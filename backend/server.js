const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { MongoClient, ObjectId } = require('mongodb');
require('dotenv').config();

const app = express();
app.use(express.json());

// MongoDB connection
const MONGO_URI = process.env.MONGO_URI;
const MONGO_DB = process.env.MONGO_DB || 'lms_database';

let db;

async function connectToDatabase() {
  try {
    const client = new MongoClient(MONGO_URI);
    await client.connect();
    db = client.db(MONGO_DB);
    console.log('Connected to MongoDB');
  } catch (error) {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  }
}

connectToDatabase();

// Middleware for authentication
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({ success: false, error: 'Invalid token' });
  }
};

// Authentication endpoints
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, confirm_password, first_name, last_name, role } = req.body;

    if (password !== confirm_password) {
      return res.status(400).json({ success: false, error: 'Passwords do not match' });
    }

    const existingUser = await db.collection('users').findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'User already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = {
      email,
      password: hashedPassword,
      first_name,
      last_name,
      role: role || 'student',
      is_email_verified: false,
      created_at: new Date(),
      is_active: true
    };

    const result = await db.collection('users').insertOne(user);
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: {
        id: result.insertedId,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_email_verified: user.is_email_verified
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await db.collection('users').findOne({ email });
    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: user._id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_email_verified: user.is_email_verified
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/auth/check-password-strength', (req, res) => {
  const { password } = req.body;
  const strength = {
    score: 0,
    feedback: []
  };

  if (password.length < 8) {
    strength.feedback.push('Password should be at least 8 characters long');
  } else {
    strength.score += 1;
  }

  if (!/[a-z]/.test(password)) {
    strength.feedback.push('Password should contain at least one lowercase letter');
  } else {
    strength.score += 1;
  }

  if (!/[A-Z]/.test(password)) {
    strength.feedback.push('Password should contain at least one uppercase letter');
  } else {
    strength.score += 1;
  }

  if (!/[0-9]/.test(password)) {
    strength.feedback.push('Password should contain at least one number');
  } else {
    strength.score += 1;
  }

  if (!/[^a-zA-Z0-9]/.test(password)) {
    strength.feedback.push('Password should contain at least one special character');
  } else {
    strength.score += 1;
  }

  res.json({
    success: true,
    strength: strength.score,
    feedback: strength.feedback
  });
});

app.post('/api/auth/refresh-token', authenticateToken, (req, res) => {
  try {
    const token = jwt.sign(
      { id: req.user.id, email: req.user.email, role: req.user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      token
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/auth/dashboard', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;

    let dashboardData = {};

    if (userRole === 'student') {
      const enrolledCourses = await db.collection('enrollments')
        .find({ user_id: userId })
        .toArray();

      dashboardData = {
        enrolled_courses: enrolledCourses.length,
        recent_courses: enrolledCourses.slice(0, 5)
      };
    } else if (userRole === 'teacher') {
      const createdCourses = await db.collection('courses')
        .find({ created_by: userId })
        .toArray();

      dashboardData = {
        created_courses: createdCourses.length,
        recent_courses: createdCourses.slice(0, 5)
      };
    }

    res.json({
      success: true,
      dashboard: dashboardData
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Student endpoints
app.get('/api/courses/student/dashboard', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const enrolledCourses = await db.collection('enrollments')
      .find({ user_id: userId })
      .toArray();

    const courseIds = enrolledCourses.map(e => e.course_id);
    const courses = await db.collection('courses')
      .find({ _id: { $in: courseIds } })
      .toArray();

    res.json({
      success: true,
      courses
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/student/enrolled', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const enrollments = await db.collection('enrollments')
      .find({ user_id: userId })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    const courseIds = enrollments.map(e => e.course_id);
    const courses = await db.collection('courses')
      .find({ _id: { $in: courseIds } })
      .toArray();

    res.json({
      success: true,
      courses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('enrollments').countDocuments({ user_id: userId })
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/courses/student/enroll', authenticateToken, async (req, res) => {
  try {
    const { course_id } = req.body;
    const userId = req.user.id;

    const existingEnrollment = await db.collection('enrollments').findOne({
      user_id: userId,
      course_id: new ObjectId(course_id)
    });

    if (existingEnrollment) {
      return res.status(400).json({ success: false, error: 'Already enrolled in this course' });
    }

    const enrollment = {
      user_id: userId,
      course_id: new ObjectId(course_id),
      enrolled_at: new Date(),
      status: 'active'
    };

    await db.collection('enrollments').insertOne(enrollment);
    res.status(201).json({
      success: true,
      message: 'Successfully enrolled in course'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/student/progress', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { course_id } = req.query;

    const progress = await db.collection('lecture_progress')
      .find({ user_id: userId, course_id: new ObjectId(course_id) })
      .toArray();

    res.json({
      success: true,
      progress
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/student/certificates', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const certificates = await db.collection('certificates')
      .find({ user_id: userId })
      .toArray();

    res.json({
      success: true,
      certificates
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/student/assignments', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const assignments = await db.collection('assignments')
      .find({ user_id: userId })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    res.json({
      success: true,
      assignments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('assignments').countDocuments({ user_id: userId })
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/student/grades', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const grades = await db.collection('grades')
      .find({ user_id: userId })
      .toArray();

    res.json({
      success: true,
      grades
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Teacher endpoints
app.get('/api/courses/teacher/dashboard', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const createdCourses = await db.collection('courses')
      .find({ created_by: userId })
      .toArray();

    const totalStudents = await db.collection('enrollments')
      .countDocuments({ course_id: { $in: createdCourses.map(c => c._id) } });

    res.json({
      success: true,
      dashboard: {
        total_courses: createdCourses.length,
        total_students,
        recent_courses: createdCourses.slice(0, 5)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/teacher/courses', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const courses = await db.collection('courses')
      .find({ created_by: userId })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    res.json({
      success: true,
      courses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('courses').countDocuments({ created_by: userId })
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/courses/teacher/create', authenticateToken, async (req, res) => {
  try {
    const { title, description, category, level, price } = req.body;
    const userId = req.user.id;

    const course = {
      title,
      description,
      category,
      level,
      price: parseFloat(price),
      created_by: userId,
      created_at: new Date(),
      is_active: true
    };

    const result = await db.collection('courses').insertOne(course);
    res.status(201).json({
      success: true,
      message: 'Course created successfully',
      course: { ...course, _id: result.insertedId }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/teacher/students', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { course_id } = req.query;

    const enrollments = await db.collection('enrollments')
      .find({ course_id: new ObjectId(course_id) })
      .toArray();

    const studentIds = enrollments.map(e => e.user_id);
    const students = await db.collection('users')
      .find({ _id: { $in: studentIds } })
      .toArray();

    res.json({
      success: true,
      students
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/teacher/analytics', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { course_id } = req.query;

    const enrollments = await db.collection('enrollments')
      .find({ course_id: new ObjectId(course_id) })
      .toArray();

    const analytics = {
      total_enrollments: enrollments.length,
      enrollments_by_month: {},
      completion_rate: 0
    };

    res.json({
      success: true,
      analytics
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/teacher/assignments', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { course_id } = req.query;

    const assignments = await db.collection('assignments')
      .find({ course_id: new ObjectId(course_id), created_by: userId })
      .toArray();

    res.json({
      success: true,
      assignments
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/courses/teacher/assignments', authenticateToken, async (req, res) => {
  try {
    const { course_id, title, description, due_date, points } = req.body;
    const userId = req.user.id;

    const assignment = {
      course_id: new ObjectId(course_id),
      title,
      description,
      due_date: new Date(due_date),
      points: parseInt(points),
      created_by: userId,
      created_at: new Date(),
      is_active: true
    };

    const result = await db.collection('assignments').insertOne(assignment);
    res.status(201).json({
      success: true,
      message: 'Assignment created successfully',
      assignment: { ...assignment, _id: result.insertedId }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Admin endpoints
app.get('/api/admin/dashboard', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const totalUsers = await db.collection('users').countDocuments();
    const totalCourses = await db.collection('courses').countDocuments();
    const totalEnrollments = await db.collection('enrollments').countDocuments();

    res.json({
      success: true,
      dashboard: {
        total_users: totalUsers,
        total_courses: totalCourses,
        total_enrollments: totalEnrollments
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/admin/users', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const { page = 1, limit = 10, role } = req.query;
    const query = role ? { role } : {};

    const users = await db.collection('users')
      .find(query)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    res.json({
      success: true,
      users,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('users').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/admin/courses', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const { page = 1, limit = 10 } = req.query;

    const courses = await db.collection('courses')
      .find({})
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    res.json({
      success: true,
      courses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('courses').countDocuments()
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/admin/analytics', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const analytics = {
      total_users: await db.collection('users').countDocuments(),
      total_courses: await db.collection('courses').countDocuments(),
      total_enrollments: await db.collection('enrollments').countDocuments(),
      active_users: await db.collection('users').countDocuments({ is_active: true })
    };

    res.json({
      success: true,
      analytics
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/admin/users/:id/status', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const { id } = req.params;
    const { is_active } = req.body;

    await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { $set: { is_active, updated_at: new Date() } }
    );

    res.json({
      success: true,
      message: 'User status updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/admin/courses/:id', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const { id } = req.params;

    await db.collection('courses').updateOne(
      { _id: new ObjectId(id) },
      { $set: { is_active: false, deleted_at: new Date() } }
    );

    res.json({
      success: true,
      message: 'Course deleted successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Course endpoints
app.get('/api/courses', async (req, res) => {
  try {
    const { page = 1, limit = 10, category, level } = req.query;
    const query = { is_active: true };
    
    if (category) query.category = category;
    if (level) query.level = level;

    const courses = await db.collection('courses')
      .find(query)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    res.json({
      success: true,
      courses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('courses').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const course = await db.collection('courses').findOne({ _id: new ObjectId(id) });

    if (!course) {
      return res.status(404).json({ success: false, error: 'Course not found' });
    }

    res.json({
      success: true,
      course
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/:id/lectures', async (req, res) => {
  try {
    const { id } = req.params;
    const lectures = await db.collection('lectures')
      .find({ course_id: new ObjectId(id) })
      .sort({ order: 1 })
      .toArray();

    res.json({
      success: true,
      lectures
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/courses/:id/enrollments', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const enrollments = await db.collection('enrollments')
      .find({ course_id: new ObjectId(id) })
      .toArray();

    res.json({
      success: true,
      enrollments
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Lecture endpoints
app.get('/api/lectures', async (req, res) => {
  try {
    const { course_id, page = 1, limit = 10 } = req.query;
    const query = course_id ? { course_id: new ObjectId(course_id) } : {};

    const lectures = await db.collection('lectures')
      .find(query)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();

    res.json({
      success: true,
      lectures,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('lectures').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/lectures/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const lecture = await db.collection('lectures').findOne({ _id: new ObjectId(id) });

    if (!lecture) {
      return res.status(404).json({ success: false, error: 'Lecture not found' });
    }

    res.json({
      success: true,
      lecture
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/lectures', authenticateToken, async (req, res) => {
  try {
    const { course_id, title, description, video_url, duration, order } = req.body;
    const userId = req.user.id;

    const lecture = {
      course_id: new ObjectId(course_id),
      title,
      description,
      video_url,
      duration: parseInt(duration),
      order: parseInt(order),
      created_by: userId,
      created_at: new Date(),
      is_active: true
    };

    const result = await db.collection('lectures').insertOne(lecture);
    res.status(201).json({
      success: true,
      message: 'Lecture created successfully',
      lecture: { ...lecture, _id: result.insertedId }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/lectures/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    const lecture = await db.collection('lectures').findOne({ _id: new ObjectId(id) });
    if (!lecture) {
      return res.status(404).json({ success: false, error: 'Lecture not found' });
    }

    if (lecture.created_by !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    await db.collection('lectures').updateOne(
      { _id: new ObjectId(id) },
      { $set: { ...updates, updated_at: new Date() } }
    );

    res.json({
      success: true,
      message: 'Lecture updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/lectures/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const lecture = await db.collection('lectures').findOne({ _id: new ObjectId(id) });
    if (!lecture) {
      return res.status(404).json({ success: false, error: 'Lecture not found' });
    }

    if (lecture.created_by !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    await db.collection('lectures').updateOne(
      { _id: new ObjectId(id) },
      { $set: { is_active: false, deleted_at: new Date() } }
    );

    res.json({
      success: true,
      message: 'Lecture deleted successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Course Materials Endpoints
app.get('/api/courses/:courseId/materials', authenticateToken, async (req, res) => {
  try {
    const { courseId } = req.params;
    const { page = 1, limit = 10, type, search } = req.query;
    
    const query = { course_id: courseId };
    if (type) query.type = type;
    if (search) query.title = { $regex: search, $options: 'i' };
    
    const materials = await db.collection('course_materials')
      .find(query)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();
    
    res.json({
      success: true,
      materials,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('course_materials').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/courses/:courseId/materials', authenticateToken, async (req, res) => {
  try {
    const { courseId } = req.params;
    const { title, description, type, file_url, file_size } = req.body;
    
    const material = {
      course_id: courseId,
      title,
      description,
      type,
      file_url,
      file_size,
      uploaded_by: req.user.id,
      uploaded_at: new Date(),
      is_active: true
    };
    
    const result = await db.collection('course_materials').insertOne(material);
    res.status(201).json({
      success: true,
      message: 'Course material uploaded successfully',
      material: { ...material, _id: result.insertedId }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Live Classes Endpoints
app.get('/api/live-classes', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 10, status } = req.query;
    
    const query = {};
    if (status) query.status = status;
    
    const classes = await db.collection('live_classes')
      .find(query)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();
    
    res.json({
      success: true,
      classes,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('live_classes').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/live-classes', authenticateToken, async (req, res) => {
  try {
    const { title, description, start_time, duration, zoom_meeting_id } = req.body;
    
    const liveClass = {
      title,
      description,
      start_time: new Date(start_time),
      duration: parseInt(duration),
      zoom_meeting_id,
      created_by: req.user.id,
      created_at: new Date(),
      status: 'scheduled',
      participants: []
    };
    
    const result = await db.collection('live_classes').insertOne(liveClass);
    res.status(201).json({
      success: true,
      message: 'Live class created successfully',
      live_class: { ...liveClass, _id: result.insertedId }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Notifications Endpoints
app.get('/api/notifications', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 10, unread_only } = req.query;
    
    const query = { user_id: req.user.id };
    if (unread_only === 'true') query.is_read = false;
    
    const notifications = await db.collection('notifications')
      .find(query)
      .sort({ created_at: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();
    
    res.json({
      success: true,
      notifications,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('notifications').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    await db.collection('notifications').updateOne(
      { _id: new ObjectId(id), user_id: req.user.id },
      { $set: { is_read: true, read_at: new Date() } }
    );
    
    res.json({
      success: true,
      message: 'Notification marked as read'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Analytics Endpoints
app.get('/api/analytics/dashboard', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    
    let analytics = {};
    
    if (userRole === 'student') {
      const enrolledCourses = await db.collection('enrollments').countDocuments({ user_id: userId });
      const completedLectures = await db.collection('lecture_progress').countDocuments({ 
        user_id: userId, 
        is_completed: true 
      });
      
      analytics = {
        enrolled_courses: enrolledCourses,
        completed_lectures: completedLectures,
        progress_percentage: 0
      };
    } else if (userRole === 'teacher') {
      const createdCourses = await db.collection('courses').countDocuments({ created_by: userId });
      const totalStudents = await db.collection('enrollments').distinct('user_id', { 
        course_id: { $in: await db.collection('courses').distinct('_id', { created_by: userId }) }
      });
      
      analytics = {
        created_courses: createdCourses,
        total_students: totalStudents.length,
        total_revenue: 0
      };
    }
    
    res.json({
      success: true,
      analytics
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Streaming Endpoints
app.get('/api/streaming/:lectureId', authenticateToken, async (req, res) => {
  try {
    const { lectureId } = req.params;
    
    const lecture = await db.collection('lectures').findOne({ _id: new ObjectId(lectureId) });
    if (!lecture) {
      return res.status(404).json({ success: false, error: 'Lecture not found' });
    }
    
    const enrollment = await db.collection('enrollments').findOne({
      user_id: req.user.id,
      course_id: lecture.course_id
    });
    
    if (!enrollment) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }
    
    res.json({
      success: true,
      lecture: {
        id: lecture._id,
        title: lecture.title,
        video_url: lecture.video_url,
        duration: lecture.duration,
        description: lecture.description
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Enhanced Course Management
app.put('/api/courses/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;
    
    const course = await db.collection('courses').findOne({ _id: new ObjectId(id) });
    if (!course) {
      return res.status(404).json({ success: false, error: 'Course not found' });
    }
    
    if (course.created_by !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }
    
    const result = await db.collection('courses').updateOne(
      { _id: new ObjectId(id) },
      { $set: { ...updates, updated_at: new Date() } }
    );
    
    res.json({
      success: true,
      message: 'Course updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Lecture Progress Tracking
app.post('/api/lectures/:id/progress', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { progress_percentage, is_completed } = req.body;
    
    const progress = {
      user_id: req.user.id,
      lecture_id: new ObjectId(id),
      progress_percentage: parseFloat(progress_percentage),
      is_completed: is_completed === true,
      updated_at: new Date()
    };
    
    await db.collection('lecture_progress').updateOne(
      { user_id: req.user.id, lecture_id: new ObjectId(id) },
      { $set: progress },
      { upsert: true }
    );
    
    res.json({
      success: true,
      message: 'Progress updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Course Search and Filtering
app.get('/api/courses/search', authenticateToken, async (req, res) => {
  try {
    const { q, category, level, page = 1, limit = 10 } = req.query;
    
    const query = { is_active: true };
    if (q) query.$or = [
      { title: { $regex: q, $options: 'i' } },
      { description: { $regex: q, $options: 'i' } }
    ];
    if (category) query.category = category;
    if (level) query.level = level;
    
    const courses = await db.collection('courses')
      .find(query)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .toArray();
    
    res.json({
      success: true,
      courses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: await db.collection('courses').countDocuments(query)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// User Profile Management
app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const user = await db.collection('users').findOne({ _id: new ObjectId(req.user.id) });
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    res.json({
      success: true,
      user: {
        id: user._id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_email_verified: user.is_email_verified,
        created_at: user.created_at
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const { first_name, last_name, email } = req.body;
    
    const updates = {};
    if (first_name) updates.first_name = first_name;
    if (last_name) updates.last_name = last_name;
    if (email) updates.email = email;
    
    await db.collection('users').updateOne(
      { _id: new ObjectId(req.user.id) },
      { $set: { ...updates, updated_at: new Date() } }
    );
    
    res.json({
      success: true,
      message: 'Profile updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Course Enrollment Status
app.get('/api/courses/:id/enrollment-status', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const enrollment = await db.collection('enrollments').findOne({
      user_id: req.user.id,
      course_id: new ObjectId(id)
    });
    
    res.json({
      success: true,
      is_enrolled: !!enrollment,
      enrollment_date: enrollment ? enrollment.enrolled_at : null
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Course Categories
app.get('/api/courses/categories', authenticateToken, async (req, res) => {
  try {
    const categories = await db.collection('courses').distinct('category');
    res.json({
      success: true,
      categories
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// System Health Check
app.get('/api/health', async (req, res) => {
  try {
    const dbStatus = await db.admin().ping();
    res.json({
      success: true,
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message
    });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});