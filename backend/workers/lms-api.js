// LMS Backend API - Cloudflare Workers
// This replaces your Django backend with serverless functions
// Keeps MongoDB Atlas for database, uses R2 for file storage

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const path = url.pathname;
        
        // CORS headers
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
        };
        
        // Handle preflight requests
        if (request.method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }
        
        // Health check endpoint
        if (path === '/api/health') {
            return new Response(JSON.stringify({
                status: 'healthy',
                service: 'LMS API',
                provider: 'Cloudflare Workers',
                database: 'MongoDB Atlas',
                storage: 'Cloudflare R2',
                timestamp: new Date().toISOString()
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // API routes
        if (path.startsWith('/api/')) {
            return await handleApiRequest(request, path, env, corsHeaders);
        }
        
        // Default response
        return new Response(JSON.stringify({
            message: 'LMS API - Cloudflare Workers',
            description: 'Serverless backend for Learning Management System',
            database: 'MongoDB Atlas (NoSQL)',
            file_storage: 'Cloudflare R2 (Encrypted & Chunked)',
            endpoints: [
                '/api/health',
                '/api/auth/*',
                '/api/courses/*',
                '/api/lectures/*',
                '/api/live-classes/*',
                '/api/notifications/*',
                '/api/analytics/*',
                '/api/materials/*'
            ]
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
};

async function handleApiRequest(request, path, env, corsHeaders) {
    try {
        // Route to appropriate handler
        if (path.startsWith('/api/auth/')) {
            return await handleAuth(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/courses/')) {
            return await handleCourses(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/lectures/')) {
            return await handleLectures(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/live-classes/')) {
            return await handleLiveClasses(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/notifications/')) {
            return await handleNotifications(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/analytics/')) {
            return await handleAnalytics(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/materials/')) {
            return await handleMaterials(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/user/')) {
            return await handleUser(request, path, env, corsHeaders);
        }
        
        return new Response(JSON.stringify({ error: 'Endpoint not found' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Authentication handlers
async function handleAuth(request, path, env, corsHeaders) {
    const url = new URL(request.url);
    
    if (path === '/api/auth/login' && request.method === 'POST') {
        try {
            const body = await request.json();
            const { email, password } = body;
            
            // Call MongoDB Atlas for authentication
            const authResult = await authenticateUser(email, password);
            
            if (authResult.success) {
                // Store session in KV
                const sessionId = generateSessionId();
                await env.LMS_SESSIONS.put(sessionId, JSON.stringify({
                    user_id: authResult.user_id,
                    email: email,
                    role: authResult.role,
                    created_at: new Date().toISOString(),
                    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString() // 24 hours
                }), { expirationTtl: 86400 });
                
                return new Response(JSON.stringify({
                    success: true,
                    message: 'Login successful',
                    session_id: sessionId,
                    user: {
                        id: authResult.user_id,
                        email: email,
                        role: authResult.role
                    }
                }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            } else {
                return new Response(JSON.stringify({
                    success: false,
                    message: 'Invalid credentials'
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
        } catch (error) {
            return new Response(JSON.stringify({
                success: false,
                message: 'Authentication error',
                error: error.message
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path === '/api/auth/logout' && request.method === 'POST') {
        const authHeader = request.headers.get('Authorization');
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const sessionId = authHeader.substring(7);
            await env.LMS_SESSIONS.delete(sessionId);
        }
        
        return new Response(JSON.stringify({
            success: true,
            message: 'Logout successful'
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
    
    return new Response(JSON.stringify({ message: 'Auth endpoint - Available methods: POST /login, POST /logout' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Course handlers
async function handleCourses(request, path, env, corsHeaders) {
    const url = new URL(request.url);
    
    if (path === '/api/courses' && request.method === 'GET') {
        try {
            // Get courses from MongoDB Atlas
            const courses = await getCoursesFromMongo();
            
            return new Response(JSON.stringify({
                success: true,
                courses: courses
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({
                success: false,
                message: 'Error fetching courses',
                error: error.message
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path.startsWith('/api/courses/') && path.includes('/materials/') && request.method === 'POST') {
        try {
            // Handle file upload to R2
            const formData = await request.formData();
            const file = formData.get('file');
            const courseId = path.split('/')[3]; // Extract course ID from path
            
            if (!file) {
                return new Response(JSON.stringify({
                    success: false,
                    message: 'No file provided'
                }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            // Upload to R2 with encryption and chunking
            const uploadResult = await uploadFileToR2(file, courseId, env);
            
            if (uploadResult.success) {
                // Save metadata to MongoDB Atlas
                await saveMaterialMetadata(uploadResult, courseId);
                
                return new Response(JSON.stringify({
                    success: true,
                    message: 'File uploaded successfully',
                    file_info: uploadResult
                }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            } else {
                return new Response(JSON.stringify({
                    success: false,
                    message: 'File upload failed',
                    error: uploadResult.error
                }), {
                    status: 500,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
        } catch (error) {
            return new Response(JSON.stringify({
                success: false,
                message: 'File upload error',
                error: error.message
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    return new Response(JSON.stringify({ message: 'Courses endpoint - Available methods: GET /courses, POST /courses/{id}/materials' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Materials handlers
async function handleMaterials(request, path, env, corsHeaders) {
    const url = new URL(request.url);
    
    if (path.startsWith('/api/materials/') && request.method === 'GET') {
        try {
            const courseSlug = path.split('/')[3];
            const materialId = path.split('/')[4];
            
            if (materialId) {
                // Get specific material
                const material = await getMaterialFromMongo(courseSlug, materialId);
                if (material) {
                    // Generate signed URL for R2 download
                    const downloadUrl = await generateSignedUrl(material.r2_key, env);
                    material.download_url = downloadUrl;
                    
                    return new Response(JSON.stringify({
                        success: true,
                        material: material
                    }), {
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                    });
                } else {
                    return new Response(JSON.stringify({
                        success: false,
                        message: 'Material not found'
                    }), {
                        status: 404,
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                    });
                }
            } else {
                // Get all materials for course
                const materials = await getCourseMaterialsFromMongo(courseSlug);
                
                return new Response(JSON.stringify({
                    success: true,
                    materials: materials
                }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
        } catch (error) {
            return new Response(JSON.stringify({
                success: false,
                message: 'Error fetching materials',
                error: error.message
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    return new Response(JSON.stringify({ message: 'Materials endpoint - Available methods: GET /materials/{course_slug}, GET /materials/{course_slug}/{material_id}' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Placeholder handlers for other endpoints
async function handleLectures(request, path, env, corsHeaders) {
    return new Response(JSON.stringify({ message: 'Lectures endpoint - Coming soon' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

async function handleLiveClasses(request, path, env, corsHeaders) {
    return new Response(JSON.stringify({ message: 'Live Classes endpoint - Coming soon' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

async function handleNotifications(request, path, env, corsHeaders) {
    return new Response(JSON.stringify({ message: 'Notifications endpoint - Coming soon' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

async function handleAnalytics(request, path, env, corsHeaders) {
    return new Response(JSON.stringify({ message: 'Analytics endpoint - Coming soon' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Utility functions
function generateSessionId() {
    return 'session_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
}

// MongoDB Atlas integration functions (to be implemented)
async function authenticateUser(email, password) {
    // TODO: Implement MongoDB Atlas authentication
    // This will call your existing MongoDB Atlas database
    return {
        success: true,
        user_id: 'user_123',
        role: 'student'
    };
}

async function getCoursesFromMongo() {
    // TODO: Implement MongoDB Atlas course fetching
    return [
        { id: '1', title: 'Sample Course', description: 'A sample course' }
    ];
}

async function saveMaterialMetadata(uploadResult, courseId) {
    // TODO: Implement MongoDB Atlas metadata saving
    console.log('Saving material metadata:', uploadResult, courseId);
}

async function getMaterialFromMongo(courseSlug, materialId) {
    // TODO: Implement MongoDB Atlas material fetching
    return {
        id: materialId,
        title: 'Sample Material',
        r2_key: 'course_materials/123/sample.pdf'
    };
}

async function getCourseMaterialsFromMongo(courseSlug) {
    // TODO: Implement MongoDB Atlas materials fetching
    return [
        { id: '1', title: 'Sample Material 1' },
        { id: '2', title: 'Sample Material 2' }
    ];
}

// R2 integration functions
async function uploadFileToR2(file, courseId, env) {
    // TODO: Implement R2 file upload with encryption and chunking
    return {
        success: true,
        r2_key: `course_materials/${courseId}/${file.name}`,
        size: file.size,
        type: file.type
    };
}

async function generateSignedUrl(r2Key, env) {
    // TODO: Implement R2 signed URL generation
    return `https://r2.example.com/${r2Key}?token=signed_token`;
}

// User management handlers
async function handleUser(request, path, env, corsHeaders) {
    const url = new URL(request.url);
    
    if (path === '/api/user/profile' && request.method === 'GET') {
        return await getUserProfile(request, env, corsHeaders);
    } else if (path === '/api/user/profile' && request.method === 'PUT') {
        return await updateUserProfile(request, env, corsHeaders);
    } else if (path === '/api/user/edit-name' && request.method === 'PUT') {
        return await editUserName(request, env, corsHeaders);
    } else if (path === '/api/user/edit-password' && request.method === 'PUT') {
        return await editUserPassword(request, env, corsHeaders);
    }
    
    return new Response(JSON.stringify({ error: 'User endpoint not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

async function getUserProfile(request, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Authorization header required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const token = authHeader.split(' ')[1];
        const user = await getUserFromToken(token, env);
        
        if (!user) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Invalid token' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        return new Response(JSON.stringify({
            success: true,
            user: {
                id: user.id,
                email: user.email,
                first_name: user.first_name,
                last_name: user.last_name,
                role: user.role,
                is_email_verified: user.is_email_verified,
                created_at: user.created_at
            }
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

async function updateUserProfile(request, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Authorization header required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const token = authHeader.split(' ')[1];
        const user = await getUserFromToken(token, env);
        
        if (!user) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Invalid token' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const body = await request.json();
        const { first_name, last_name, email } = body;
        
        // Update user profile in MongoDB via Vultr adapter
        const updateResult = await updateUserInMongo(user.id, { first_name, last_name, email });
        
        if (updateResult.success) {
            return new Response(JSON.stringify({
                success: true,
                message: 'Profile updated successfully'
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } else {
            return new Response(JSON.stringify({ 
                success: false, 
                error: updateResult.error 
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

async function editUserName(request, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Authorization header required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const token = authHeader.split(' ')[1];
        const user = await getUserFromToken(token, env);
        
        if (!user) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Invalid token' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const body = await request.json();
        const { first_name, last_name } = body;
        
        if (!first_name || !last_name) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'First name and last name are required' 
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Update user name in MongoDB via Vultr adapter
        const updateResult = await updateUserNameInMongo(user.id, first_name.trim(), last_name.trim());
        
        if (updateResult.success) {
            return new Response(JSON.stringify({
                success: true,
                message: 'Name updated successfully',
                user: {
                    first_name: first_name.trim(),
                    last_name: last_name.trim()
                }
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } else {
            return new Response(JSON.stringify({ 
                success: false, 
                error: updateResult.error 
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

async function editUserPassword(request, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Authorization header required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const token = authHeader.split(' ')[1];
        const user = await getUserFromToken(token, env);
        
        if (!user) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Invalid token' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const body = await request.json();
        const { current_password, new_password, confirm_password } = body;
        
        if (!current_password || !new_password || !confirm_password) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Current password, new password, and confirm password are required' 
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        if (new_password !== confirm_password) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'New password and confirm password do not match' 
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Update user password in MongoDB via Vultr adapter
        const updateResult = await updateUserPasswordInMongo(user.id, current_password, new_password);
        
        if (updateResult.success) {
            return new Response(JSON.stringify({
                success: true,
                message: 'Password updated successfully'
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } else {
            return new Response(JSON.stringify({ 
                success: false, 
                error: updateResult.error 
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Helper functions for MongoDB operations via Vultr adapter
async function getUserFromToken(token, env) {
    // TODO: Implement token validation and user retrieval
    // This would call the Vultr adapter to validate the token and get user info
    return {
        id: 'user_123',
        email: 'user@example.com',
        first_name: 'John',
        last_name: 'Doe',
        role: 'student',
        is_email_verified: true,
        created_at: new Date().toISOString()
    };
}

async function updateUserInMongo(userId, updates) {
    // TODO: Implement user profile update via Vultr adapter
    return { success: true };
}

async function updateUserNameInMongo(userId, first_name, last_name) {
    // TODO: Implement user name update via Vultr adapter
    return { success: true };
}

async function updateUserPasswordInMongo(userId, current_password, new_password) {
    // TODO: Implement user password update via Vultr adapter
    return { success: true };
}
