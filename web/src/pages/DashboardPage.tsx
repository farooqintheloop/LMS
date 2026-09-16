import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { LogOut, User, BookOpen, GraduationCap, Users, Settings, Edit2, X, Key } from 'lucide-react';
import DarkModeToggle from '../components/DarkModeToggle';
import UploadProgressBar from '../components/UploadProgressBar';
import './DashboardPage.css';
import '../styles/upload.css';
import { apiService } from '../services/apiService';

const DashboardPage: React.FC = () => {
  const { user, logout, isAuthenticated, updateUser } = useAuth();
  const navigate = useNavigate();

  // Redirect to login if not authenticated
  React.useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const [studentCourses, setStudentCourses] = React.useState<Array<any>>([]);
  const [studentStats, setStudentStats] = React.useState<{ enrolled?: number; completed?: number; studyTime?: number; certificates?: number }>({});
  const [teacherCourses, setTeacherCourses] = React.useState<Array<any>>([]);
  const [teacherStats, setTeacherStats] = React.useState<{ totalCourses?: number; totalStudents?: number; activeClasses?: number; }>({});
  const [adminOverview, setAdminOverview] = React.useState<{ total_students?: number; total_teachers?: number; total_courses?: number; total_lectures?: number; total_enrollments?: number }>({});
  const [adminCourses, setAdminCourses] = React.useState<any[]>([]);
  const [showAddCourse, setShowAddCourse] = React.useState(false);
  const [showAddLecture, setShowAddLecture] = React.useState(false);
  const [courseForm, setCourseForm] = React.useState<{ title: string; description: string; category: string; level: string; price: string; instructor_id: string; instructor_name: string }>({ title: '', description: '', category: '', level: 'beginner', price: '', instructor_id: '', instructor_name: '' });
  const [lectureForm, setLectureForm] = React.useState<{ courseId: string; title: string; description: string; file?: File }>({ courseId: '', title: '', description: '', file: undefined });
  const [availableTeachers, setAvailableTeachers] = React.useState<Array<{ _id: string; first_name: string; last_name: string; email: string }>>([]);
  const [availableCourses, setAvailableCourses] = React.useState<Array<{ _id: string; title: string; description: string; category: string; level: string; price: number; instructor_name?: string; created_at?: string; status?: string; }>>([]);
  const [modalError, setModalError] = React.useState<string | null>(null);
  const [modalLoading, setModalLoading] = React.useState(false);
  const [uploadProgress, setUploadProgress] = React.useState<{ visible: boolean; courseId: string; title: string }>({ 
    visible: false, 
    courseId: '', 
    title: '' 
  });
  const [loadingDash, setLoadingDash] = React.useState(false);
  const [dashError, setDashError] = React.useState<string | null>(null);
  const [showEditName, setShowEditName] = React.useState(false);
  const [editNameForm, setEditNameForm] = React.useState<{ firstName: string; lastName: string }>({ firstName: '', lastName: '' });
  const [editNameLoading, setEditNameLoading] = React.useState(false);
  const [editNameError, setEditNameError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const loadDash = async () => {
      if (!isAuthenticated || !user) return;
      try {
        setLoadingDash(true);
        setDashError(null);
        if (user.role === 'student') {
          const [dash, enrolledList, progress] = await Promise.all([
            apiService.getStudentDashboard(),
            apiService.getStudentEnrolled(),
            apiService.getStudentProgress(),
          ]);
          setStudentCourses(dash.courses || []);
          setStudentStats({
            enrolled: (enrolledList || []).length,
            completed: progress?.completed_lectures ?? 0,
            studyTime: progress?.study_time_hours ?? 0,
            certificates: progress?.certificates ?? 0,
          });
        } else if (user.role === 'teacher') {
          const [tDash, tStudents] = await Promise.all([
            apiService.getTeacherDashboard(),
            apiService.getTeacherStudents({ page: 1 }),
          ]);
          const courses = tDash?.dashboard?.courses || tDash?.courses || [];
          setTeacherCourses(courses);
          setTeacherStats({
            totalCourses: courses.length,
            totalStudents: (tStudents?.students || []).length,
            activeClasses: (tDash?.dashboard?.live_classes || []).length,
          });
        } else if (user.role === 'admin') {
          const [adm, adminCoursesData] = await Promise.all([
            apiService.getAdminDashboard(),
            apiService.getAdminCourses()
          ]);
          const overview = adm?.overview || adm || {};
          setAdminOverview({
            total_students: overview.total_students ?? 0,
            total_teachers: overview.total_teachers ?? 0,
            total_courses: overview.total_courses ?? 0,
            total_lectures: overview.total_lectures ?? 0,
            total_enrollments: overview.total_enrollments ?? 0,
          });
          setAdminCourses(adminCoursesData.courses || []);
        }
      } catch (e: any) {
        setDashError(e.message || 'Failed to load dashboard');
      } finally {
        setLoadingDash(false);
      }
    };
    loadDash();
  }, [isAuthenticated, user]);

  // Preload teachers when Add Course modal opens
  React.useEffect(() => {
    if (showAddCourse) {
      loadTeachers();
    }
  }, [showAddCourse]);

  // Preload courses when Add Lecture modal opens
  React.useEffect(() => {
    if (showAddLecture) {
      loadCourses();
    }
  }, [showAddLecture]);

  const loadTeachers = async () => {
    try {
      const response = await apiService.getAvailableTeachers();
      setAvailableTeachers(response.instructors || []);
    } catch (e: any) {
      console.error('Failed to load teachers:', e.message);
    }
  };

  const loadCourses = async () => {
    try {
      const response = await apiService.getAdminCourses();
      setAvailableCourses(response.courses || []);
    } catch (e: any) {
      console.error('Failed to load courses:', e.message);
    }
  };

  if (!isAuthenticated || !user) return null;

  const getRoleIcon = (role: string) => {
    switch (role) {
      case 'student':
        return <GraduationCap className="role-icon" />;
      case 'teacher':
        return <Users className="role-icon" />;
      case 'admin':
        return <Settings className="role-icon" />;
      default:
        return <User className="role-icon" />;
    }
  };


  const getWelcomeMessage = (role: string) => {
    switch (role) {
      case 'student':
        return 'Continue your learning journey';
      case 'teacher':
        return 'Manage your courses and students';
      case 'admin':
        return 'Manage the learning platform';
      default:
        return 'Welcome to your dashboard';
    }
  };

  const handleEditNameClick = () => {
    setEditNameForm({
      firstName: user?.firstName || '',
      lastName: user?.lastName || ''
    });
    setEditNameError(null);
    setShowEditName(true);
  };

  const handleEditNameSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setEditNameLoading(true);
    setEditNameError(null);

    try {
      const response = await apiService.editUserName(editNameForm.firstName, editNameForm.lastName);
      
      if (response.success) {
        // Update the user context with new name
        updateUser(editNameForm.firstName, editNameForm.lastName);
        setShowEditName(false);
        setEditNameForm({ firstName: '', lastName: '' });
      } else {
        setEditNameError(response.message || 'Failed to update name');
      }
    } catch (error: any) {
      setEditNameError(error.message || 'Failed to update name');
    } finally {
      setEditNameLoading(false);
    }
  };

  const handleEditNameCancel = () => {
    setShowEditName(false);
    setEditNameForm({ firstName: '', lastName: '' });
    setEditNameError(null);
  };

  return (
    <div className="dashboard-page">
      {/* Navigation Header */}
      <nav className="navbar">
        <div className="nav-container">
          <div className="nav-brand">
            <div className="brand-logo">
              <BookOpen className="logo-icon" />
            </div>
            <span className="brand-name">LMS</span>
          </div>
          <div className="nav-menu">
            <a href="#" className="nav-link">Courses</a>
            <a href="#" className="nav-link">Progress</a>
            <a href="#" className="nav-link">Community</a>
            <a href="#" className="nav-link">Help</a>
          </div>
          <div className="nav-actions">
            <DarkModeToggle size="medium" />
            <div className="user-info">
              <div className="user-avatar">
                {getRoleIcon(user.role)}
              </div>
              <div className="user-details">
                <div className="user-name-container">
                  <div className="user-name">{user.name}</div>
                  <button 
                    className="edit-name-btn" 
                    onClick={handleEditNameClick}
                    title="Edit name"
                  >
                    <Edit2 size={14} />
                  </button>
                </div>
                <div className="user-role">{user.role.charAt(0).toUpperCase() + user.role.slice(1)}</div>
              </div>
            </div>
            <button className="update-password-button" onClick={() => navigate('/forgot-password')}>
              <Key size={20} />
              Update Password
            </button>
            <button className="logout-button" onClick={handleLogout}>
              <LogOut size={20} />
              Logout
            </button>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="dashboard-main">
        <div className="dashboard-container">
          {/* Welcome Section */}
          <div className="welcome-section">
            <div className="welcome-content">
              <h1 className="welcome-title">Welcome back, {user.firstName}!</h1>
              <p className="welcome-subtitle">{getWelcomeMessage(user.role)}</p>
            </div>
            {user.role === 'student' && (
              <div className="welcome-actions">
                <button className="btn btn-primary">Continue Learning</button>
                <button className="btn btn-outline">Browse Courses</button>
              </div>
            )}
          </div>

          {/* Stats Section - Real data for student */}
          <div className="stats-section">
            <div className="stat-card" onClick={() => { if (user.role === 'admin') setShowAddCourse(true); }}>
              <div className="stat-icon">📚</div>
              <div className="stat-content">
                <div className="stat-number">{
                  user.role === 'student' ? (studentStats.enrolled ?? 0)
                  : user.role === 'teacher' ? (teacherStats.totalCourses ?? 0)
                  : (adminOverview.total_courses ?? 0)
                }</div>
                <div className="stat-label">{
                  user.role === 'student' ? 'Enrolled Courses'
                  : user.role === 'teacher' ? 'Courses'
                  : 'Total Courses'
                }</div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon">🎓</div>
              <div className="stat-content">
                <div className="stat-number">{
                  user.role === 'student' ? (studentStats.completed ?? 0)
                  : user.role === 'teacher' ? (teacherStats.totalStudents ?? 0)
                  : (adminOverview.total_students ?? 0)
                }</div>
                <div className="stat-label">{
                  user.role === 'student' ? 'Completed'
                  : user.role === 'teacher' ? 'Students'
                  : 'Total Students'
                }</div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon">⏱️</div>
            <div className="stat-content">
                <div className="stat-number">{
                  user.role === 'student' ? `${studentStats.studyTime ?? 0}h`
                  : user.role === 'teacher' ? (teacherStats.activeClasses ?? 0)
                  : (adminOverview.total_teachers ?? 0)
                }</div>
                <div className="stat-label">{
                  user.role === 'student' ? 'Study Time'
                  : user.role === 'teacher' ? 'Live Classes'
                  : 'Total Teachers'
                }</div>
              </div>
            </div>
            <div className="stat-card" onClick={() => { if (user.role === 'admin') setShowAddLecture(true); }}>
              <div className="stat-icon">🏆</div>
            <div className="stat-content">
                <div className="stat-number">{
                  user.role === 'student' ? (studentStats.certificates ?? 0)
                  : user.role === 'teacher' ? (teacherStats.totalCourses ?? 0)
                  : (adminOverview.total_lectures ?? 0)
                }</div>
                <div className="stat-label">{
                  user.role === 'student' ? 'Certificates'
                  : user.role === 'teacher' ? 'Active Courses'
                  : 'Total Lectures'
                }</div>
              </div>
            </div>
          </div>

          {/* Content Grid - Student Courses (read-only) */}
          <div className="content-grid">
            {/* Recent Courses */}
            <div className="content-section">
              <div className="section-header">
                <h2>{user.role === 'student' ? 'Your Courses' : user.role === 'teacher' ? 'Recent Courses' : 'All Courses'}</h2>
                <a href="#" className="view-all">View All</a>
              </div>
              <div className="courses-grid">
                {user.role === 'student' ? (
                  loadingDash ? (
                    <div className="course-card"><div className="course-content"><h3>Loading your courses...</h3></div></div>
                  ) : dashError ? (
                    <div className="course-card"><div className="course-content"><h3>{dashError}</h3></div></div>
                  ) : studentCourses.length === 0 ? (
                    <div className="course-card"><div className="course-content"><h3>No courses found</h3></div></div>
                  ) : (
                    studentCourses.map((c) => (
                      <div key={c._id} className="course-card">
                        <div className="course-image">
                          <BookOpen className="course-icon" />
                        </div>
                        <div className="course-content">
                          <h3>{c.title}</h3>
                          <p>{c.description}</p>
                          <div className="course-info-grid">
                            <div className="info-box">
                              <span className="info-label">Category</span>
                              <span className="info-value">{c.category}</span>
                            </div>
                            <div className="info-box">
                              <span className="info-label">Level</span>
                              <span className="info-value">{(c.level || '').toString()}</span>
                            </div>
                            {c.instructor_name && (
                              <div className="info-box">
                                <span className="info-label">Instructor</span>
                                <span className="info-value">{c.instructor_name}</span>
                              </div>
                            )}
                            {c.status && (
                              <div className="info-box">
                                <span className="info-label">Status</span>
                                <span className="info-value status-badge">{c.status}</span>
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )
                ) : user.role === 'teacher' ? (
                  loadingDash ? (
                    <div className="course-card"><div className="course-content"><h3>Loading your courses...</h3></div></div>
                  ) : dashError ? (
                    <div className="course-card"><div className="course-content"><h3>{dashError}</h3></div></div>
                  ) : teacherCourses.length === 0 ? (
                    <div className="course-card"><div className="course-content"><h3>No courses yet</h3></div></div>
                  ) : (
                    teacherCourses.map((c, idx) => (
                      <div key={c._id ?? idx} className="course-card">
                        <div className="course-image">
                          <GraduationCap className="course-icon" />
                        </div>
                        <div className="course-content">
                          <h3>{c.title ?? c.name ?? 'Untitled Course'}</h3>
                          <p>{c.description ?? ''}</p>
                          <div className="course-info-grid">
                            {c.category && (
                              <div className="info-box">
                                <span className="info-label">Category</span>
                                <span className="info-value">{c.category}</span>
                              </div>
                            )}
                            {c.level && (
                              <div className="info-box">
                                <span className="info-label">Level</span>
                                <span className="info-value">{c.level}</span>
                              </div>
                            )}
                            {c.status && (
                              <div className="info-box">
                                <span className="info-label">Status</span>
                                <span className="info-value status-badge">{c.status}</span>
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )
                ) : (
                  // Admin - All Courses
                  loadingDash ? (
                    <div className="course-card"><div className="course-content"><h3>Loading all courses...</h3></div></div>
                  ) : dashError ? (
                    <div className="course-card"><div className="course-content"><h3>{dashError}</h3></div></div>
                  ) : adminCourses.length === 0 ? (
                    <div className="course-card"><div className="course-content"><h3>No courses found</h3></div></div>
                  ) : (
                    adminCourses.map((c) => (
                      <div key={c._id || c.id} className="course-card">
                        <div className="course-image">
                          <BookOpen className="course-icon" />
                        </div>
                        <div className="course-content">
                          <h3>{c.title}</h3>
                          <p>{c.description}</p>
                          <div className="course-info-grid">
                            {c.category && (
                              <div className="info-box">
                                <span className="info-label">Category</span>
                                <span className="info-value">{c.category}</span>
                              </div>
                            )}
                            {c.level && (
                              <div className="info-box">
                                <span className="info-label">Level</span>
                                <span className="info-value">{c.level}</span>
                              </div>
                            )}
                            {c.instructor_name && (
                              <div className="info-box">
                                <span className="info-label">Instructor</span>
                                <span className="info-value">{c.instructor_name}</span>
                              </div>
                            )}
                            {c.status && (
                              <div className="info-box">
                                <span className="info-label">Status</span>
                                <span className="info-value status-badge">{c.status}</span>
                              </div>
                            )}
                            {c.price && (
                              <div className="info-box">
                                <span className="info-label">Price</span>
                                <span className="info-value price-badge">${c.price}</span>
                              </div>
                            )}
                            {c.enrolled_students_count && (
                              <div className="info-box">
                                <span className="info-label">Enrolled</span>
                                <span className="info-value enrolled-badge">{c.enrolled_students_count} students</span>
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="content-section">
              <div className="section-header">
                <h2>Quick Actions</h2>
              </div>
              <div className="actions-grid">
                {user.role === 'student' && (
                  <button className="action-card">
                    <BookOpen className="action-icon" />
                    <span>Browse Courses</span>
                  </button>
                )}
                {user.role === 'student' && (
                  <button className="action-card">
                    <GraduationCap className="action-icon" />
                    <span>My Progress</span>
                  </button>
                )}
                <button className="action-card">
                  <Users className="action-icon" />
                  <span>Community</span>
                </button>
                <button className="action-card">
                  <Settings className="action-icon" />
                  <span>Settings</span>
                </button>
              </div>
            </div>
          </div>

          {/* Account Information */}
          <div className="account-section">
            <div className="section-header">
              <h2>Account Information</h2>
            </div>
            <div className="account-card">
              <div className="account-info">
                <div className="info-item">
                  <label>Full Name:</label>
                  <span>{user.name}</span>
                </div>
                <div className="info-item">
                  <label>Email:</label>
                  <span>{user.email}</span>
                </div>
                <div className="info-item">
                  <label>Role:</label>
                  <span className="role-badge">{user.role}</span>
                </div>
                <div className="info-item">
                  <label>Member Since:</label>
                  <span>January 2024</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="dashboard-footer">
        <div className="footer-content">
          <p>&copy; 2024 LMS. All rights reserved.</p>
          <div className="footer-links">
            <a href="#">Privacy Policy</a>
            <a href="#">Terms of Service</a>
            <a href="#">Contact</a>
          </div>
        </div>
      </footer>

      {/* Admin Modals */}
      {user.role === 'admin' && showAddCourse && (
        <div className="modal-backdrop" onClick={() => setShowAddCourse(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h3>Add Course</h3>
            {modalError && <div className="error-message"><div className="error-text">{modalError}</div></div>}
            <div className="form-group">
              <input className="form-input" placeholder="Title" value={courseForm.title} onChange={(e) => setCourseForm({ ...courseForm, title: e.target.value })} />
            </div>
            <div className="form-group">
              <input className="form-input" placeholder="Category" value={courseForm.category} onChange={(e) => setCourseForm({ ...courseForm, category: e.target.value })} />
            </div>
            <div className="form-group">
              <input className="form-input" placeholder="Level (beginner/intermediate/advanced)" value={courseForm.level} onChange={(e) => setCourseForm({ ...courseForm, level: e.target.value })} />
            </div>
            <div className="form-group">
              <input className="form-input" placeholder="Price" value={courseForm.price} onChange={(e) => setCourseForm({ ...courseForm, price: e.target.value })} />
            </div>
            <div className="form-group">
              <select 
                className="form-input" 
                value={courseForm.instructor_id} 
                onChange={(e) => {
                  const selectedTeacher = availableTeachers.find(t => t._id === e.target.value);
                  setCourseForm({ 
                    ...courseForm, 
                    instructor_id: e.target.value,
                    instructor_name: selectedTeacher ? `${selectedTeacher.first_name} ${selectedTeacher.last_name}` : ''
                  });
                }}
                onFocus={loadTeachers}
              >
                <option value="">Select Instructor</option>
                {availableTeachers.map((teacher) => (
                  <option key={teacher._id} value={teacher._id}>
                    {teacher.first_name} {teacher.last_name} ({teacher.email})
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <textarea className="form-input" placeholder="Description" value={courseForm.description} onChange={(e) => setCourseForm({ ...courseForm, description: e.target.value })} />
            </div>
            <div className="modal-actions">
              <button className="btn btn-outline" onClick={() => setShowAddCourse(false)}>Cancel</button>
              <button className="btn btn-primary" disabled={modalLoading || !courseForm.title?.trim() || !courseForm.description?.trim() || !courseForm.category?.trim() || !courseForm.level?.trim() || !courseForm.instructor_id?.trim()} onClick={async () => {
                try {
                  setModalLoading(true); setModalError(null);
                  // Debug payload in console
                  try {
                    console.groupCollapsed('[UI ▶] Create Course Payload');
                    console.log({
                      title: courseForm.title,
                      description: courseForm.description,
                      category: courseForm.category,
                      level: courseForm.level,
                      price: courseForm.price ? Number(courseForm.price) : undefined,
                      instructor_id: courseForm.instructor_id,
                      instructor_name: courseForm.instructor_name,
                    });
                    console.log(`[UI ▶] title="${courseForm.title}" desc.len=${courseForm.description?.length||0} category="${courseForm.category}" level="${courseForm.level}" instructor_id=${courseForm.instructor_id} instructor_name="${courseForm.instructor_name}"`);
                    console.groupEnd();
                  } catch (_) {}
                  // Ensure instructor_name is populated even if not set by onChange
                  let instructorName = courseForm.instructor_name;
                  if (!instructorName) {
                    const selectedTeacher = availableTeachers.find(t => t._id === courseForm.instructor_id);
                    instructorName = selectedTeacher ? `${selectedTeacher.first_name} ${selectedTeacher.last_name}` : '';
                  }
                  const payload = {
                    title: (courseForm.title || '').trim(),
                    description: (courseForm.description || '').trim(),
                    category: (courseForm.category || 'General').trim(),
                    level: (courseForm.level || 'beginner').trim(),
                    price: courseForm.price ? Number(courseForm.price) : undefined,
                    instructor_id: (courseForm.instructor_id || '').trim(),
                    instructor_name: (instructorName || '').trim(),
                  };
                  // Final sanity: prevent empty strings for required fields
                  if (!payload.title || !payload.description || !payload.category || !payload.level || !payload.instructor_id || !payload.instructor_name) {
                    throw new Error('Please fill all required fields before submitting');
                  }
                  console.log('[UI ▶] Final Payload', payload);
                  await apiService.createAdminCourse(payload as any);
                  setShowAddCourse(false);
                  // Reset form
                  setCourseForm({ title: '', description: '', category: '', level: 'beginner', price: '', instructor_id: '', instructor_name: '' });
                  // Reload dashboard to show new course
                  window.location.reload();
                } catch (e: any) {
                  // Try to surface API error message
                  const message = e?.response?.data?.error || e?.message || 'Failed to create course';
                  console.error('[UI ◀] Create Course Error:', e?.response?.data || e);
                  setModalError(message);
                } finally { setModalLoading(false); }
              }}>{modalLoading ? 'Creating...' : 'Create'}</button>
            </div>
          </div>
        </div>
      )}

      {/* Upload Progress Bar */}
      {uploadProgress.visible && (
        <UploadProgressBar 
          isVisible={uploadProgress.visible} 
          courseId={uploadProgress.courseId} 
          title={uploadProgress.title} 
        />
      )}

      {user.role === 'admin' && showAddLecture && (
        <div className="modal-backdrop" onClick={() => setShowAddLecture(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h3>Add Lecture</h3>
            {modalError && <div className="error-message"><div className="error-text">{modalError}</div></div>}
            <div className="form-group">
              <select 
                className="form-input" 
                value={lectureForm.courseId} 
                onChange={(e) => setLectureForm({ ...lectureForm, courseId: e.target.value })}
                onFocus={loadCourses}
              >
                <option value="">Select Course</option>
                {availableCourses.map((course) => (
                  <option key={course._id} value={course._id}>
                    {course.title} - {course.category} ({course.level})
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <input className="form-input" placeholder="Title" value={lectureForm.title} onChange={(e) => setLectureForm({ ...lectureForm, title: e.target.value })} />
            </div>
            <div className="form-group">
              <textarea className="form-input" placeholder="Description" value={lectureForm.description} onChange={(e) => setLectureForm({ ...lectureForm, description: e.target.value })} />
            </div>
            <div className="form-group">
              <input className="form-input" type="file" onChange={(e) => setLectureForm({ ...lectureForm, file: e.target.files?.[0] })} />
              {lectureForm.file && (
                <div className="file-info">
                  <span>Selected file: {lectureForm.file.name}</span>
                  <span>Size: {(lectureForm.file.size / (1024 * 1024)).toFixed(2)} MB</span>
                  {lectureForm.file.size > 10 * 1024 * 1024 && (
                    <span className="chunked-upload-notice">This file will be uploaded in chunks for better reliability</span>
                  )}
                </div>
              )}
            </div>
            <div className="modal-actions">
              <button className="btn btn-outline" onClick={() => setShowAddLecture(false)}>Cancel</button>
              <button className="btn btn-primary" disabled={modalLoading || !lectureForm.courseId || !lectureForm.title} onClick={async () => {
                try {
                  setModalLoading(true); 
                  setModalError(null);
                  
                  // Set up upload progress tracking for large files
                  if (lectureForm.file && lectureForm.file.size > 10 * 1024 * 1024) {
                    // Set up progress tracking
                    setUploadProgress({
                      visible: true,
                      courseId: lectureForm.courseId,
                      title: lectureForm.title
                    });
                    
                    // Add event listener for upload completion
                    const handleUploadComplete = (event: Event) => {
                      const customEvent = event as CustomEvent;
                      if (customEvent.detail?.courseId === lectureForm.courseId && 
                          customEvent.detail?.title === lectureForm.title) {
                        // Hide upload progress after a delay
                        setTimeout(() => {
                          setUploadProgress({ visible: false, courseId: '', title: '' });
                        }, 2000);
                        
                        // Remove event listener
                        window.removeEventListener('upload-complete', handleUploadComplete as EventListener);
                        
                        // Reload dashboard to show new lecture
                        window.location.reload();
                      }
                    };
                    
                    window.addEventListener('upload-complete', handleUploadComplete as EventListener);
                  }
                  
                  await apiService.uploadAdminLecture({
                    courseId: lectureForm.courseId,
                    title: lectureForm.title,
                    description: lectureForm.description || undefined,
                    file: lectureForm.file,
                  });
                  
                  // For small files (not using chunked upload), we can close the modal immediately
                  if (!lectureForm.file || lectureForm.file.size <= 10 * 1024 * 1024) {
                  setShowAddLecture(false);
                  // Reset form
                  setLectureForm({ courseId: '', title: '', description: '', file: undefined });
                  // Reload dashboard to show new lecture
                  window.location.reload();
                  } else {
                    // For large files, we'll keep the modal open until upload is complete
                    // but hide it to show the progress bar
                    setShowAddLecture(false);
                  }
                } catch (e: any) {
                  setModalError(e.message || 'Failed to upload lecture');
                  // Hide progress bar on error
                  setUploadProgress({ visible: false, courseId: '', title: '' });
                } finally { 
                  setModalLoading(false); 
                }
              }}>{modalLoading ? 'Preparing Upload...' : 'Upload'}</button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Name Modal */}
      {showEditName && (
        <div className="modal-backdrop" onClick={handleEditNameCancel}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Edit Name</h3>
              <button className="modal-close" onClick={handleEditNameCancel}>
                <X size={20} />
              </button>
            </div>
            
            {editNameError && (
              <div className="error-message">
                <div className="error-text">{editNameError}</div>
              </div>
            )}
            
            <form onSubmit={handleEditNameSubmit}>
              <div className="form-group">
                <label className="form-label">First Name</label>
                <input 
                  className="form-input" 
                  placeholder="Enter first name" 
                  value={editNameForm.firstName} 
                  onChange={(e) => setEditNameForm({ ...editNameForm, firstName: e.target.value })}
                  required
                />
              </div>
              
              <div className="form-group">
                <label className="form-label">Last Name</label>
                <input 
                  className="form-input" 
                  placeholder="Enter last name" 
                  value={editNameForm.lastName} 
                  onChange={(e) => setEditNameForm({ ...editNameForm, lastName: e.target.value })}
                  required
                />
              </div>
              
              <div className="modal-actions">
                <button 
                  type="button" 
                  className="btn btn-outline" 
                  onClick={handleEditNameCancel}
                  disabled={editNameLoading}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn btn-primary" 
                  disabled={editNameLoading || !editNameForm.firstName.trim() || !editNameForm.lastName.trim()}
                >
                  {editNameLoading ? 'Updating...' : 'Update Name'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default DashboardPage;

