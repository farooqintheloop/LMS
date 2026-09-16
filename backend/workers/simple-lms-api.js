// Simple LMS API - Cloudflare Workers
// This is a working version that will run immediately

export default {
    async fetch(request, env, ctx) {
        const startTimeMs = Date.now();
        const url = new URL(request.url);
        const path = url.pathname;
        
        console.log(`[MAIN DEBUG] Worker fetch called for path: ${path}`);
        console.log(`[MAIN DEBUG] Request method: ${request.method}`);
        
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
        
        // Secure admin log views
        if (path === '/admin/logs' || path === '/admin/logs/html') {
            const authHeader = request.headers.get('Authorization') || '';
            const tokenFromHeader = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
            const tokenFromQuery = new URL(request.url).searchParams.get('token') || '';
            const token = tokenFromHeader || tokenFromQuery;
            if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
                return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            const limit = Number(new URL(request.url).searchParams.get('limit') || '50');
            const list = await env.LMS_SESSIONS.list({ prefix: 'logs:', limit: isNaN(limit) ? 50 : Math.min(limit, 500) });
            const items = await Promise.all((list.keys || []).map(async (k) => {
                const v = await env.LMS_SESSIONS.get(k.name);
                try { return JSON.parse(v || '{}'); } catch { return { raw: v }; }
            }));
            if (path === '/admin/logs/html') {
                const rows = items.map(i => `<tr><td>${i.timestamp}</td><td>${i.method}</td><td>${i.path}</td><td>${i.status}</td><td>${i.duration_ms}</td><td>${i.cf_ray || ''}</td><td>${i.ip || ''}</td></tr>`).join('');
                const html = `<!doctype html><html><head><meta charset="utf-8"><title>Request Logs</title><style>body{font-family:Arial, sans-serif;margin:20px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:8px}th{background:#f5f5f5;text-align:left}tr:nth-child(even){background:#fafafa}</style></head><body><h1>Request Logs</h1><table><thead><tr><th>Time</th><th>Method</th><th>Path</th><th>Status</th><th>Duration (ms)</th><th>CF-Ray</th><th>IP</th></tr></thead><tbody>${rows}</tbody></table></body></html>`;
                return new Response(html, { headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' } });
            }
            return new Response(JSON.stringify({ success: true, logs: items }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        
        // Handle the request using existing routes, then log
        const response = await routeRequest(request, env, corsHeaders);
        const durationMs = Date.now() - startTimeMs;
        ctx.waitUntil(logRequest(env, request, response, durationMs));
        return response;
    }
};

async function routeRequest(request, env, corsHeaders) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    // Health check endpoint
    if (path === '/api/health') {
        return new Response(JSON.stringify({
            status: 'healthy',
            service: 'LMS API',
            provider: 'Cloudflare Workers',
            database: 'MongoDB Atlas (NoSQL)',
            file_storage: 'Cloudflare R2 (Encrypted & Chunked)',
            timestamp: new Date().toISOString(),
            message: 'Your LMS is running on Cloudflare Workers!'
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
        status: 'running',
        endpoints: [
            '/api/health',
            '/api/auth/*',
            '/api/courses/*',
            '/api/lectures/*',
            '/api/live-classes/*',
            '/api/notifications/*',
            '/api/analytics/*',
            '/api/materials/*',
            '/api/user/*',
            '/api/chat/*',
            '/api/admin/add-admin',
            '/api/admin/delete-admin/*',
            '/api/admin/list-admins'
        ],
        instructions: 'Copy this code to your Cloudflare Worker and deploy!'
    }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

async function logRequest(env, request, response, durationMs) {
    try {
        const url = new URL(request.url);
        const key = `logs:${Date.now()}:${request.headers.get('CF-RAY') || 'no-ray'}`;
        const record = {
            timestamp: new Date().toISOString(),
            method: request.method,
            path: url.pathname,
            query: url.search,
            status: response.status,
            duration_ms: durationMs,
            ip: request.headers.get('CF-Connecting-IP') || null,
            cf_ray: request.headers.get('CF-RAY') || null,
            user_agent: request.headers.get('User-Agent') || null,
        };
        await env.LMS_SESSIONS.put(key, JSON.stringify(record), { expirationTtl: 60 * 60 * 24 * 7 }); // 7 days
    } catch (e) {
        // Swallow logging errors
    }
}

async function handleApiRequest(request, path, env, corsHeaders) {
    try {
        console.log(`[ROUTING DEBUG] Handling API request for path: ${path}`);
        console.log(`[ROUTING DEBUG] Request method: ${request.method}`);
        
        
        // Route to appropriate handler
        if (path.startsWith('/api/auth/')) {
            console.log(`[ROUTING DEBUG] Routing to handleAuth`);
            return await handleAuth(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/courses/student/')) {
            console.log(`[ROUTING DEBUG] Routing to handleStudent`);
            return await handleStudent(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/courses/teacher/')) {
            console.log(`[ROUTING DEBUG] Routing to handleTeacher`);
            console.log(`[ROUTING DEBUG] Path matches teacher pattern: ${path}`);
            try {
                const result = await handleTeacher(request, path, env, corsHeaders);
                console.log(`[ROUTING DEBUG] Teacher handler completed successfully`);
                return result;
            } catch (error) {
                console.log(`[ROUTING DEBUG] Teacher handler failed:`, error.message);
                return new Response(JSON.stringify({
                    success: false,
                    message: 'ROUTING ERROR in teacher handler',
                    error: error.message,
                    stack: error.stack,
                    path: path
                }), {
                    status: 500,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
        } else if (path.startsWith('/api/admin/')) {
            console.log(`[ROUTING DEBUG] Routing to handleAdmin`);
            return await handleAdmin(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/courses') || path.startsWith('/api/courses/')) {
            console.log(`[ROUTING DEBUG] Routing to handleCourses`);
            return await handleCourses(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/lectures/')) {
            console.log(`[ROUTING DEBUG] Routing to handleLectures`);
            return await handleLectures(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/live-classes')) {
            console.log(`[ROUTING DEBUG] Routing to handleLiveClasses`);
            return await handleLiveClasses(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/notifications/')) {
            console.log(`[ROUTING DEBUG] Routing to handleNotifications`);
            return await handleNotifications(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/analytics/')) {
            console.log(`[ROUTING DEBUG] Routing to handleAnalytics`);
            return await handleAnalytics(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/materials/')) {
            console.log(`[ROUTING DEBUG] Routing to handleMaterials`);
            return await handleMaterials(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/user/')) {
            console.log(`[ROUTING DEBUG] Routing to handleUser`);
            return await handleUser(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/streaming/')) {
            console.log(`[ROUTING DEBUG] Routing to handleStreaming`);
            return await handleStreaming(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/chat/')) {
            console.log(`[ROUTING DEBUG] Routing to handleChat`);
            return await handleChat(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/user/')) {
            console.log(`[ROUTING DEBUG] Routing to handleUser`);
            return await handleUser(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/admin/add-admin') || path.startsWith('/api/admin/delete-admin') || path.startsWith('/api/admin/list-admins')) {
            console.log(`[ROUTING DEBUG] Routing to handleAdminManagement`);
            return await handleAdminManagement(request, path, env, corsHeaders);
        } else if (path.startsWith('/api/admin/upload-chunk')) {
            console.log(`[ROUTING DEBUG] Routing to handleChunkUpload`);
            return await handleChunkUpload(request, path, env, corsHeaders);
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
    if (path === '/api/auth/login' && request.method === 'POST') {
        try {
            const body = await request.json();
            const { email, password, remember_me } = body || {};
            if (!email || !password) {
                return new Response(JSON.stringify({ success: false, message: 'Email and password required' }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: JSON.stringify({ email, password, remember_me })
            });
            
            // Check if response is JSON
            const contentType = resp.headers.get('content-type') || '';
            if (!contentType.includes('application/json')) {
                const text = await resp.text();
                return new Response(JSON.stringify({ 
                    success: false, 
                    message: 'Invalid response format from backend',
                    error: 'Expected JSON but received: ' + contentType
                }), {
                    status: 500,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ success: false, message: 'Authentication error', error: error.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path === '/api/auth/register' && request.method === 'POST') {
        try {
            const body = await request.json();
            const { email, password, confirm_password, first_name, last_name, role } = body || {};
            
            if (!email || !password || !confirm_password || !first_name || !last_name) {
                return new Response(JSON.stringify({ 
                    success: false, 
                    message: 'Email, password, confirm_password, first_name, and last_name are required' 
                }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/register`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: JSON.stringify({ 
                    email, 
                    password, 
                    confirm_password,
                    first_name, 
                    last_name, 
                    role: role || 'student' 
                })
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Registration error', 
                error: error.message 
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path === '/api/auth/check-password-strength' && request.method === 'POST') {
        try {
            const body = await request.json();
            const { password } = body || {};
            
            if (!password) {
                return new Response(JSON.stringify({ 
                    success: false, 
                    message: 'Password is required' 
                }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/check-password-strength`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: JSON.stringify({ password })
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Password strength check error', 
                error: error.message 
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path === '/api/auth/dashboard' && request.method === 'GET') {
        try {
            const authHeader = request.headers.get('Authorization') || '';
            const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
            
            if (!token) {
                return new Response(JSON.stringify({ 
                    success: false, 
                    message: 'Authorization token required' 
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/dashboard`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN,
                    'Authorization': `Bearer ${token}`
                }
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Dashboard error', 
                error: error.message 
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path === '/api/auth/refresh-token' && request.method === 'POST') {
        try {
            const body = await request.json();
            const { refresh } = body || {};
            
            if (!refresh) {
                return new Response(JSON.stringify({ 
                    success: false, 
                    message: 'Refresh token is required' 
                }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/refresh-token`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: JSON.stringify({ refresh })
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Token refresh error', 
                error: error.message 
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path === '/api/auth/logout' && request.method === 'POST') {
        return new Response(JSON.stringify({
            success: true,
            message: 'Logout successful (Mock)'
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
    
    // Forgot password endpoint
    if (path === '/api/auth/forgot-password' && request.method === 'POST') {
        try {
            const body = await request.text();
            const { email } = JSON.parse(body);
            
            if (!email) {
    return new Response(JSON.stringify({ 
                    success: false, 
                    error: 'Email is required' 
                }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/forgot-password`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: body
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
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
    
    // Verify reset code endpoint
    if (path === '/api/auth/verify-reset-code' && request.method === 'POST') {
        try {
            const body = await request.text();
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/verify-reset-code`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: body
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
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
    
    // Reset password endpoint
    if (path === '/api/auth/reset-password' && request.method === 'POST') {
        try {
            const body = await request.text();
            
            const resp = await fetch(`${env.BACKEND_URL}/api/auth/reset-password`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-adapter-token': env.BACKEND_TOKEN
                },
                body: body
            });
            
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
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
    
    return new Response(JSON.stringify({ 
        message: 'Auth endpoint - Available methods: POST /login, POST /register, POST /logout, POST /check-password-strength, GET /dashboard, POST /refresh-token, POST /forgot-password, POST /verify-reset-code, POST /reset-password',
        note: 'Currently using mock responses. Connect to MongoDB Atlas for real authentication.'
    }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Course handlers
async function handleCourses(request, path, env, corsHeaders) {
    if (path === '/api/courses' && request.method === 'GET') {
        try {
            const resp = await fetch(`${env.BACKEND_URL}/api/courses`, {
                headers: { 'x-adapter-token': env.BACKEND_TOKEN }
            });
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ success: false, message: 'Courses fetch error', error: error.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path.startsWith('/api/courses/') && path.includes('/lectures') && request.method === 'GET') {
        try {
            const resp = await fetch(`${env.BACKEND_URL}${path}`, {
                headers: { 'x-adapter-token': env.BACKEND_TOKEN }
            });
            const data = await resp.json();
            return new Response(JSON.stringify(data), {
                status: resp.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } catch (error) {
            return new Response(JSON.stringify({ success: false, message: 'Lectures fetch error', error: error.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    if (path.startsWith('/api/courses/') && path.includes('/materials/') && request.method === 'POST') {
        try {
            const formData = await request.formData();
            const file = formData.get('file');
            const courseId = path.split('/')[3];
            
            if (!file) {
                return new Response(JSON.stringify({
                    success: false,
                    message: 'No file provided'
                }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                });
            }
            
            // TODO: Implement R2 file upload with encryption and chunking
            const mockUploadResult = {
                success: true,
                message: 'File upload successful (Mock)',
                file_info: {
                    name: file.name,
                    size: file.size,
                    type: file.type,
                    course_id: courseId,
                    note: 'This is a mock upload. Connect to R2 for real file storage.'
                }
            };
            
            return new Response(JSON.stringify(mockUploadResult), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
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
    
    return new Response(JSON.stringify({ 
        message: 'Courses endpoint - Available methods: GET /courses, POST /courses/{id}/materials',
        note: 'Currently using mock responses. Connect to MongoDB Atlas and R2 for real data.'
    }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Materials handlers
async function handleMaterials(request, path, env, corsHeaders) {
    if (path.startsWith('/api/materials/') && request.method === 'GET') {
        const courseSlug = path.split('/')[3];
        const materialId = path.split('/')[4];
        
        if (materialId) {
            // Get specific material
            const mockMaterial = {
                id: materialId,
                title: 'Sample Material',
                course_slug: courseSlug,
                note: 'This is a mock material. Connect to MongoDB Atlas and R2 for real data.'
            };
            
            return new Response(JSON.stringify({
                success: true,
                material: mockMaterial
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        } else {
            // Get all materials for course
            const mockMaterials = [
                { id: '1', title: 'Lecture 1 - Introduction', course_slug: courseSlug },
                { id: '2', title: 'Lecture 2 - Basics', course_slug: courseSlug },
                { id: '3', title: 'Assignment 1', course_slug: courseSlug }
            ];
            
            return new Response(JSON.stringify({
                success: true,
                materials: mockMaterials,
                note: 'These are mock materials. Connect to MongoDB Atlas and R2 for real data.'
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
    }
    
    return new Response(JSON.stringify({ 
        message: 'Materials endpoint - Available methods: GET /materials/{course_slug}, GET /materials/{course_slug}/{material_id}',
        note: 'Currently using mock responses. Connect to MongoDB Atlas and R2 for real data.'
    }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

// Lecture handlers
async function handleLectures(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        // Forward all lecture requests to Vultr adapter (remove /api prefix)
        const vultrPath = path.replace('/api', '');
        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                ...(token && { 'Authorization': `Bearer ${token}` })
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Lecture endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Live Classes handlers
async function handleLiveClasses(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
    return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
    }), {
                status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

        // Forward all live class requests to Vultr adapter (keep /api prefix)
        const vultrPath = path;
        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        // Check if response is JSON before parsing
        const contentType = resp.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
            const text = await resp.text();
    return new Response(JSON.stringify({ 
                success: false,
                message: 'Invalid response format from backend',
                error: 'Expected JSON but received: ' + contentType
    }), {
                status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Live Classes endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Notifications handlers
async function handleNotifications(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
    return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
    }), {
                status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

        // Forward all notification requests to Vultr adapter (remove /api prefix)
        const vultrPath = path.replace('/api', '');
        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Notifications endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Analytics handlers
async function handleAnalytics(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Forward all analytics requests to Vultr adapter (remove /api prefix)
        const vultrPath = path.replace('/api', '');
        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Analytics endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Student handlers
async function handleStudent(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Preserve query string (e.g. ?course_id=...) when forwarding
        const urlObj = new URL(request.url);
        const queryString = urlObj.search || '';
        
        // Forward all student requests to Vultr adapter (keep /api prefix)
        const vultrPath = path;
        const vultrUrl = `${env.BACKEND_URL}${vultrPath}${queryString}`;

        const resp = await fetch(vultrUrl, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        // Check if response is JSON before parsing
        const contentType = resp.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
            const text = await resp.text();
            return new Response(JSON.stringify({
                success: false,
                message: 'Invalid response format from backend',
                error: 'Expected JSON but received: ' + contentType
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Student endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Teacher handlers
async function handleTeacher(request, path, env, corsHeaders) {
    try {
        const requestId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        console.log(`[TEACHER_${requestId}] ===== TEACHER REQUEST STARTED =====`);
        console.log(`[TEACHER_${requestId}] Path: ${path}`);
        console.log(`[TEACHER_${requestId}] Method: ${request.method}`);
        
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
            console.log(`[TEACHER_${requestId}] No token found, returning 401`);
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Forward all teacher requests to Vultr adapter (keep /api prefix)
        const vultrPath = path;
        const vultrUrl = `${env.BACKEND_URL}${vultrPath}`;
        
        console.log(`[TEACHER_${requestId}] Forwarding to Vultr URL: ${vultrUrl}`);
        
        // Detect multipart uploads to preserve boundary and stream body
        const originalContentType = (request.headers.get('content-type') || '').toLowerCase();
        const isMultipart = originalContentType.startsWith('multipart/form-data');
        
        console.log(`[TEACHER_${requestId}] Content Type: ${originalContentType}`);
        console.log(`[TEACHER_${requestId}] Is Multipart: ${isMultipart}`);
        
        const headers = {
            'x-adapter-token': env.BACKEND_TOKEN,
            'Authorization': `Bearer ${token}`
        };
        
        let forwardBody;
        if (request.method !== 'GET') {
            if (isMultipart) {
                console.log(`[TEACHER_${requestId}] 🔄 Processing multipart upload...`);
                // Preserve original Content-Type with boundary for Multer
                headers['Content-Type'] = request.headers.get('content-type') || 'multipart/form-data';
                // Stream the body through to backend
                forwardBody = request.body;
                console.log(`[TEACHER_${requestId}] ✅ Multipart body preserved for streaming`);
            } else {
                headers['Content-Type'] = 'application/json';
                forwardBody = await request.text();
                console.log(`[TEACHER_${requestId}] JSON body: ${forwardBody.substring(0, 200)}...`);
            }
        }
        
        console.log(`[TEACHER_${requestId}] 🔄 Forwarding request to Vultr...`);
        
        const resp = await fetch(vultrUrl, {
            method: request.method,
            headers,
            body: forwardBody
        });
        
        console.log(`[TEACHER_${requestId}] 📡 Vultr Response Status: ${resp.status}`);
        console.log(`[TEACHER_${requestId}] 📡 Vultr Response Headers:`, Object.fromEntries(resp.headers.entries()));
        
        // Check if response is JSON
        const contentType = resp.headers.get('content-type') || '';
        console.log(`[TEACHER_${requestId}] 📡 Response Content-Type: ${contentType}`);
        
        if (!contentType.includes('application/json')) {
            const text = await resp.text();
            console.log(`[TEACHER_${requestId}] ❌ NON-JSON RESPONSE FROM VULTR:`);
            console.log(`[TEACHER_${requestId}] Response Body (first 500 chars): ${text.substring(0, 500)}`);
            console.log(`[TEACHER_${requestId}] ===== TEACHER REQUEST FAILED =====`);
            
            return new Response(JSON.stringify({
                success: false,
                message: 'Invalid response format from backend',
                error: 'Expected JSON but received: ' + contentType,
                responsePreview: text.substring(0, 200),
                requestId: requestId,
                timestamp: new Date().toISOString()
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const data = await resp.json();
        console.log(`[TEACHER_${requestId}] ✅ Successfully parsed JSON response`);
        console.log(`[TEACHER_${requestId}] ===== TEACHER REQUEST COMPLETED =====`);
        
        return new Response(JSON.stringify({
            ...data,
            requestId: requestId,
            cloudflareTimestamp: new Date().toISOString()
        }), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        const errorId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        console.log(`[TEACHER_ERROR_${errorId}] Error occurred:`, error.message);
        console.log(`[TEACHER_ERROR_${errorId}] Error stack:`, error.stack);
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Teacher endpoint error', 
            error: error.message,
            errorId: errorId,
            timestamp: new Date().toISOString()
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Admin handlers
async function handleAdmin(request, path, env, corsHeaders) {
    try {
        // Public student profile endpoints (no auth required)
        const isPublicStudentEndpoint = 
            path === '/api/admin/create-student-profile' ||
            path === '/api/admin/get-student-profile';
        
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        // Only require auth for non-public endpoints
        if (!isPublicStudentEndpoint && !token) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Forward all admin requests to Vultr adapter (keep /api prefix)
        const vultrPath = path; // Don't remove /api prefix for admin endpoints
        // Preserve query string (e.g. ?email=...) when forwarding
        const urlObj = new URL(request.url);
        const queryString = urlObj.search || '';
        const requestId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);

        console.log(`[CLOUDFLARE_${requestId}] ===== CLOUDFLARE WORKER REQUEST STARTED =====`);
        console.log(`[CLOUDFLARE_${requestId}] Timestamp: ${new Date().toISOString()}`);
        console.log(`[CLOUDFLARE_${requestId}] Method: ${request.method}`);
        console.log(`[CLOUDFLARE_${requestId}] Path: ${path}`);
        console.log(`[CLOUDFLARE_${requestId}] Vultr Path: ${vultrPath}${queryString}`);
        console.log(`[CLOUDFLARE_${requestId}] Token Present: ${!!token}`);
        console.log(`[CLOUDFLARE_${requestId}] Backend URL: ${env.BACKEND_URL}`);

        // Detect multipart uploads to preserve boundary and stream body
        const originalContentType = (request.headers.get('content-type') || '').toLowerCase();
        const isMultipart = originalContentType.startsWith('multipart/form-data');
        
        console.log(`[CLOUDFLARE_${requestId}] Content Type: ${originalContentType}`);
        console.log(`[CLOUDFLARE_${requestId}] Is Multipart: ${isMultipart}`);
        console.log(`[CLOUDFLARE_${requestId}] Is Public Student Endpoint: ${isPublicStudentEndpoint}`);

        const headers = {
            'x-adapter-token': env.BACKEND_TOKEN,
        };
        
        // Only add Authorization header if token exists (skip for public endpoints)
        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }

        let forwardBody;
        if (request.method !== 'GET') {
            if (isMultipart) {
                console.log(`[CLOUDFLARE_${requestId}] 🔄 Processing multipart upload...`);
                // Preserve original Content-Type with boundary for Multer
                headers['Content-Type'] = request.headers.get('content-type') || 'multipart/form-data';
                // Stream the body through to backend
                forwardBody = request.body;
                console.log(`[CLOUDFLARE_${requestId}] ✅ Multipart body preserved for streaming`);
            } else {
                headers['Content-Type'] = 'application/json';
                forwardBody = await request.text();
                console.log(`[CLOUDFLARE_${requestId}] JSON body: ${forwardBody.substring(0, 200)}...`);
            }
        }

        console.log(`[CLOUDFLARE_${requestId}] 🔄 Forwarding request to Vultr...`);
        console.log(`[CLOUDFLARE_${requestId}] Forward Headers:`, Object.keys(headers));

        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}${queryString}`, {
            method: request.method,
            headers,
            body: forwardBody
        });
        
        console.log(`[CLOUDFLARE_${requestId}] 📡 Vultr Response Status: ${resp.status}`);
        console.log(`[CLOUDFLARE_${requestId}] 📡 Vultr Response Headers:`, Object.fromEntries(resp.headers.entries()));
        
        // Check if response is JSON
        const contentType = resp.headers.get('content-type') || '';
        console.log(`[CLOUDFLARE_${requestId}] 📡 Response Content-Type: ${contentType}`);
        
        if (!contentType.includes('application/json')) {
            const text = await resp.text();
            console.log(`[CLOUDFLARE_${requestId}] ❌ NON-JSON RESPONSE FROM VULTR:`);
            console.log(`[CLOUDFLARE_${requestId}] Content-Type: ${contentType}`);
            console.log(`[CLOUDFLARE_${requestId}] Response Body (first 500 chars): ${text.substring(0, 500)}`);
            console.log(`[CLOUDFLARE_${requestId}] ===== CLOUDFLARE WORKER REQUEST FAILED =====`);
            
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Invalid response format from backend',
                error: 'Expected JSON but received: ' + contentType,
                responsePreview: text.substring(0, 200),
                requestId: requestId,
                timestamp: new Date().toISOString()
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const data = await resp.json();
        console.log(`[CLOUDFLARE_${requestId}] ✅ JSON response received from Vultr`);
        console.log(`[CLOUDFLARE_${requestId}] Response Data:`, JSON.stringify(data, null, 2));
        console.log(`[CLOUDFLARE_${requestId}] ===== CLOUDFLARE WORKER REQUEST SUCCESSFUL =====`);
        
        return new Response(JSON.stringify({
            ...data,
            requestId: requestId,
            cloudflareTimestamp: new Date().toISOString()
        }), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        const errorId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        console.log(`[CLOUDFLARE_ERROR_${errorId}] ❌ CLOUDFLARE WORKER ERROR:`);
        console.log(`[CLOUDFLARE_ERROR_${errorId}] Error Message: ${error.message}`);
        console.log(`[CLOUDFLARE_ERROR_${errorId}] Error Stack: ${error.stack}`);
        console.log(`[CLOUDFLARE_ERROR_${errorId}] Request Method: ${request.method}`);
        console.log(`[CLOUDFLARE_ERROR_${errorId}] Request Path: ${path}`);
        console.log(`[CLOUDFLARE_ERROR_${errorId}] ===== CLOUDFLARE WORKER ERROR ENDED =====`);
        
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Admin endpoint error', 
            error: error.message,
            errorId: errorId,
            timestamp: new Date().toISOString()
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}


// Streaming handlers
async function handleStreaming(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        // Forward all streaming requests to Vultr adapter (remove /api prefix)
        const vultrPath = path.replace('/api', '');
        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Streaming endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// Chat handlers
async function handleChat(request, path, env, corsHeaders) {
    try {
        const authHeader = request.headers.get('Authorization') || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        
        if (!token) {
    return new Response(JSON.stringify({ 
                success: false, 
                message: 'Authorization token required' 
    }), {
                status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
        }
        
        // Forward all chat requests to Vultr adapter (keep /api prefix)
        const vultrPath = path;
        const resp = await fetch(`${env.BACKEND_URL}${vultrPath}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });
        
        // Check if response is JSON before parsing
        const contentType = resp.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
            const text = await resp.text();
            return new Response(JSON.stringify({
                success: false,
                message: 'Invalid response format from backend',
                error: 'Expected JSON but received: ' + contentType
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Chat endpoint error', 
            error: error.message 
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}

// User management handlers
async function handleUser(request, path, env, corsHeaders) {
    console.log(`[USER DEBUG] Handling user request for path: ${path}`);
    
    if (path === '/api/user/profile' && request.method === 'GET') {
        return await getUserProfile(request, env, corsHeaders);
    } else if (path === '/api/user/profile' && request.method === 'PUT') {
        return await updateUserProfile(request, env, corsHeaders);
    } else if (path === '/api/user/edit-name' && request.method === 'PUT') {
        return await editUserName(request, env, corsHeaders);
    } else if (path === '/api/user/edit-password' && request.method === 'PUT') {
        return await editUserPassword(request, env, corsHeaders);
    } else if (path === '/api/user/progress' ||
               path === '/api/user/sessions/start' ||
               path === '/api/user/sessions/end' ||
               path === '/api/user/progress/hours-goal') {
        // Generic proxy for user progress/session endpoints
        const authHeader = request.headers.get('Authorization') || '';
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

        // Preserve query string when forwarding (for /api/user/progress if needed later)
        const urlObj = new URL(request.url);
        const queryString = urlObj.search || '';

        const resp = await fetch(`${env.BACKEND_URL}${path}${queryString}`, {
            method: request.method,
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: request.method !== 'GET' ? await request.text() : undefined
        });

        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
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
        
        const resp = await fetch(`${env.BACKEND_URL}/api/user/profile`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            }
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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
        const body = await request.text();
        
        const resp = await fetch(`${env.BACKEND_URL}/api/user/profile`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: body
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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
        const body = await request.text();
        
        const resp = await fetch(`${env.BACKEND_URL}/api/user/edit-name`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: body
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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
        const body = await request.text();
        
        const resp = await fetch(`${env.BACKEND_URL}/api/user/edit-password`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: body
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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

async function handleAdminManagement(request, path, env, corsHeaders) {
    console.log(`[ADMIN MANAGEMENT DEBUG] Handling admin management request for path: ${path}`);
    
    if (path === '/api/admin/add-admin' && request.method === 'POST') {
        return await addAdmin(request, env, corsHeaders);
    } else if (path.startsWith('/api/admin/delete-admin/') && request.method === 'DELETE') {
        return await deleteAdmin(request, path, env, corsHeaders);
    } else if (path === '/api/admin/list-admins' && request.method === 'GET') {
        return await listAdmins(request, env, corsHeaders);
    }
    
    return new Response(JSON.stringify({ error: 'Admin management endpoint not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
}

async function addAdmin(request, env, corsHeaders) {
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
        const body = await request.text();
        
        const resp = await fetch(`${env.BACKEND_URL}/api/admin/add-admin`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            },
            body: body
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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

async function deleteAdmin(request, path, env, corsHeaders) {
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
        
        const resp = await fetch(`${env.BACKEND_URL}${path}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            }
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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

async function listAdmins(request, env, corsHeaders) {
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
        const url = new URL(request.url);
        const queryString = url.search;
        
        const resp = await fetch(`${env.BACKEND_URL}/api/admin/list-admins${queryString}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'x-adapter-token': env.BACKEND_TOKEN,
                'Authorization': `Bearer ${token}`
            }
        });
        
        const data = await resp.json();
        return new Response(JSON.stringify(data), {
            status: resp.status,
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

// Chunk upload handlers
async function handleChunkUpload(request, path, env, corsHeaders) {
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
        const requestId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        
        console.log(`[CHUNK_UPLOAD_${requestId}] ===== CHUNK UPLOAD STARTED =====`);
        console.log(`[CHUNK_UPLOAD_${requestId}] Method: ${request.method}`);
        console.log(`[CHUNK_UPLOAD_${requestId}] Path: ${path}`);
        
        // Detect multipart uploads to preserve boundary and stream body
        const originalContentType = (request.headers.get('content-type') || '').toLowerCase();
        const isMultipart = originalContentType.startsWith('multipart/form-data');
        const contentLength = parseInt(request.headers.get('content-length') || '0');
        
        console.log(`[CHUNK_UPLOAD_${requestId}] Content Type: ${originalContentType}`);
        console.log(`[CHUNK_UPLOAD_${requestId}] Is Multipart: ${isMultipart}`);
        console.log(`[CHUNK_UPLOAD_${requestId}] Content Length: ${contentLength} bytes (${(contentLength / 1024 / 1024).toFixed(2)} MB)`);
        
        // Check for large chunk uploads (> 100MB)
        if (contentLength > 100 * 1024 * 1024) {
            console.log(`[CHUNK_UPLOAD_${requestId}] ❌ Chunk too large for Workers (${(contentLength / 1024 / 1024).toFixed(2)} MB > 100 MB)`);
            return new Response(JSON.stringify({
                success: false,
                message: 'Chunk too large for Cloudflare Workers. Maximum 100MB allowed per chunk.',
                error: 'CHUNK_TOO_LARGE',
                chunkSize: contentLength,
                maxSize: 100 * 1024 * 1024,
                suggestion: 'Reduce chunk size to 50MB or less'
            }), {
                status: 413,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        const headers = {
            'x-adapter-token': env.BACKEND_TOKEN,
            'Authorization': `Bearer ${token}`
        };

        let forwardBody;
        if (isMultipart) {
            console.log(`[CHUNK_UPLOAD_${requestId}] 🔄 Processing multipart chunk upload...`);
            // Preserve original Content-Type with boundary for Multer
            headers['Content-Type'] = request.headers.get('content-type') || 'multipart/form-data';
            // Stream the body through to backend
            forwardBody = request.body;
            console.log(`[CHUNK_UPLOAD_${requestId}] ✅ Multipart chunk body preserved for streaming`);
        } else {
            headers['Content-Type'] = 'application/json';
            forwardBody = await request.text();
            console.log(`[CHUNK_UPLOAD_${requestId}] JSON chunk body: ${forwardBody.substring(0, 200)}...`);
        }

        console.log(`[CHUNK_UPLOAD_${requestId}] 🔄 Forwarding chunk to Vultr adapter...`);
        console.log(`[CHUNK_UPLOAD_${requestId}] Forward Headers:`, Object.keys(headers));

        const resp = await fetch(`${env.BACKEND_URL}${path}`, {
            method: request.method,
            headers,
            body: forwardBody
        });
        
        console.log(`[CHUNK_UPLOAD_${requestId}] 📡 Vultr Response Status: ${resp.status}`);
        console.log(`[CHUNK_UPLOAD_${requestId}] 📡 Vultr Response Headers:`, Object.fromEntries(resp.headers.entries()));
        
        // Check if response is JSON
        const contentType = resp.headers.get('content-type') || '';
        console.log(`[CHUNK_UPLOAD_${requestId}] 📡 Response Content-Type: ${contentType}`);
        
        if (!contentType.includes('application/json')) {
            const text = await resp.text();
            console.log(`[CHUNK_UPLOAD_${requestId}] ❌ NON-JSON RESPONSE FROM VULTR:`);
            console.log(`[CHUNK_UPLOAD_${requestId}] Content-Type: ${contentType}`);
            console.log(`[CHUNK_UPLOAD_${requestId}] Response Body (first 500 chars): ${text.substring(0, 500)}`);
            console.log(`[CHUNK_UPLOAD_${requestId}] ===== CHUNK UPLOAD FAILED =====`);
            
            return new Response(JSON.stringify({ 
                success: false, 
                message: 'Invalid response format from backend',
                error: 'Expected JSON but received: ' + contentType,
                responsePreview: text.substring(0, 200),
                requestId: requestId,
                timestamp: new Date().toISOString()
            }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }
        
        const data = await resp.json();
        console.log(`[CHUNK_UPLOAD_${requestId}] ✅ JSON response received from Vultr`);
        console.log(`[CHUNK_UPLOAD_${requestId}] Response Data:`, JSON.stringify(data, null, 2));
        console.log(`[CHUNK_UPLOAD_${requestId}] ===== CHUNK UPLOAD SUCCESSFUL =====`);
        
        return new Response(JSON.stringify({
            ...data,
            requestId: requestId,
            cloudflareTimestamp: new Date().toISOString()
        }), {
            status: resp.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        const errorId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        console.log(`[CHUNK_UPLOAD_ERROR_${errorId}] ❌ CHUNK UPLOAD ERROR:`);
        console.log(`[CHUNK_UPLOAD_ERROR_${errorId}] Error Message: ${error.message}`);
        console.log(`[CHUNK_UPLOAD_ERROR_${errorId}] Error Stack: ${error.stack}`);
        console.log(`[CHUNK_UPLOAD_ERROR_${errorId}] Request Method: ${request.method}`);
        console.log(`[CHUNK_UPLOAD_ERROR_${errorId}] Request Path: ${path}`);
        console.log(`[CHUNK_UPLOAD_ERROR_${errorId}] ===== CHUNK UPLOAD ERROR ENDED =====`);
        
        return new Response(JSON.stringify({ 
            success: false, 
            message: 'Chunk upload error', 
            error: error.message,
            errorId: errorId,
            timestamp: new Date().toISOString()
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
}
