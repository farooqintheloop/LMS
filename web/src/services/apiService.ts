import axios, { type AxiosResponse } from 'axios';
import { ErrorHandler } from '../utils/errorHandler';

const API_BASE_URL = 'https://lms-api-production.muheet228.workers.dev/api';

interface LoginResponse {
  success: boolean;
  message: string;
  user: {
    id: string;
    email: string;
    first_name: string;
    last_name: string;
    role: string;
  };
  token: string;
}

interface RegisterResponse {
  success: boolean;
  message: string;
  user: {
    id: string;
    email: string;
    first_name: string;
    last_name: string;
    role: string;
  };
  tokens?: {
    access: string;
    refresh: string;
  };
}

interface UserProfile {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  name: string;
}

class ApiService {
  private axiosInstance;
  private debug: boolean;

  constructor() {
    // Debug flag: enable by setting localStorage.setItem('debug_api', 'true')
    this.debug = false;
    try {
      this.debug = (typeof window !== 'undefined') && (localStorage.getItem('debug_api') === 'true');
    } catch (_) {
      // ignore
    }
    this.axiosInstance = axios.create({
      baseURL: API_BASE_URL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    });

    // Add request interceptor to attach auth token
    this.axiosInstance.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('access_token');
        if (token && !config.url?.startsWith('/auth/')) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        if (this.debug) {
          try {
            const { method, url, params, data } = config;
            // Avoid logging secrets; mask Authorization
            const safeHeaders = { ...(config.headers || {}) } as Record<string, any>;
            if (safeHeaders.Authorization) safeHeaders.Authorization = 'Bearer ***';
            // Data may be FormData; handle safely
            let body: any = data;
            if (typeof FormData !== 'undefined' && data instanceof FormData) {
              const entries: Record<string, any> = {};
              (data as FormData).forEach((v, k) => {
                entries[k] = v instanceof File ? `File(name=${(v as File).name}, size=${(v as File).size})` : v;
              });
              body = entries;
            }
            console.groupCollapsed(`[API ▶] ${method?.toUpperCase()} ${url}`);
            console.log('params:', params);
            console.log('data:', body);
            console.log('headers:', safeHeaders);
            console.groupEnd();
          } catch (_) { /* noop */ }
        }
        return config;
      },
      (error) => {
        if (this.debug) {
          console.error('[API Request Error]', error);
        }
        return Promise.reject(error);
      }
    );

    // Add response interceptor for error handling
    this.axiosInstance.interceptors.response.use(
      (response) => {
        if (this.debug) {
          try {
            const { config, status } = response;
            console.groupCollapsed(`[API ◀] ${config.method?.toUpperCase()} ${config.url} — ${status}`);
            console.log('response.data:', response.data);
            console.groupEnd();
          } catch (_) { /* noop */ }
        }
        return response;
      },
      async (error) => {
        if (error.response?.status === 401 && !error.config.url?.startsWith('/auth/')) {
          // Token expired, redirect to login
          localStorage.removeItem('access_token');
          window.location.href = '/login';
        }
        if (this.debug) {
          try {
            const { response, config } = error;
            console.groupCollapsed('[API Error]', config?.method?.toUpperCase(), config?.url);
            if (response) {
              console.error('status:', response.status);
              console.error('data:', response.data);
            } else {
              console.error('message:', error.message);
            }
            console.groupEnd();
          } catch (_) { /* noop */ }
        }
        return Promise.reject(error);
      }
    );
  }

  async getStudentDashboard(): Promise<{ courses: Array<{ _id: string; title: string; description: string; category: string; level: string; price: number; instructor_name?: string; created_at?: string; status?: string; }>; success?: boolean }>
  {
    try {
      const response = await this.axiosInstance.get('/courses/student/dashboard');
      // Normalize shape to at least contain courses array
      const data = response.data || {};
      const courses = Array.isArray(data.courses) ? data.courses : [];
      return { courses, success: data.success };
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw new Error(error.message || 'Failed to fetch student dashboard');
    }
  }

  async getStudentProgress(): Promise<{ completed_lectures?: number; total_lectures?: number; progress_percentage?: number; study_time_hours?: number; certificates?: number }>
  {
    try {
      const response = await this.axiosInstance.get('/courses/student/progress');
      return response.data || {};
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw new Error(error.message || 'Failed to fetch student progress');
    }
  }

  async getStudentEnrolled(): Promise<Array<any>> {
    try {
      const response = await this.axiosInstance.get('/courses/student/enrolled');
      return response.data?.courses || [];
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw new Error(error.message || 'Failed to fetch enrolled courses');
    }
  }

  // Teacher APIs
  async getTeacherDashboard(): Promise<{ dashboard?: any; courses?: Array<any> }>
  {
    try {
      const response = await this.axiosInstance.get('/courses/teacher/dashboard');
      return response.data || {};
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw new Error(error.message || 'Failed to fetch teacher dashboard');
    }
  }

  async getTeacherStudents(params?: { page?: number; search?: string }): Promise<{ students?: Array<any>; total?: number }>
  {
    try {
      const query = new URLSearchParams();
      if (params?.page) query.set('page', String(params.page));
      if (params?.search) query.set('search', params.search);
      const response = await this.axiosInstance.get(`/courses/teacher/students${query.toString() ? `?${query.toString()}` : ''}`);
      return response.data || {};
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw new Error(error.message || 'Failed to fetch teacher students');
    }
  }

  // Admin APIs (read-only views)
  async getAdminDashboard(): Promise<any> {
    const res = await this.axiosInstance.get('/admin/dashboard');
    return res.data;
  }

  async getAdminUsers(params?: { page?: number; limit?: number; role?: string }): Promise<any> {
    const query = new URLSearchParams();
    if (params?.page) query.set('page', String(params.page));
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.role) query.set('role', params.role);
    const res = await this.axiosInstance.get(`/admin/users${query.toString() ? `?${query.toString()}` : ''}`);
    return res.data;
  }

  async getAdminLectures(): Promise<any> {
    const res = await this.axiosInstance.get('/admin/lectures');
    return res.data;
  }

  async getAdminAnalytics(): Promise<any> {
    const res = await this.axiosInstance.get('/admin/analytics');
    return res.data;
  }

  async createAdminCourse(course: { title: string; description?: string; category?: string; level?: string; price?: number; instructor_id?: string; instructor_name?: string }): Promise<any> {
    const res = await this.axiosInstance.post('/admin/courses', course);
    return res.data;
  }

  async uploadAdminLecture(params: { courseId: string; title: string; description?: string; file?: File }): Promise<any> {
    // If file is larger than 10MB, use chunked upload
    if (params.file && params.file.size > 10 * 1024 * 1024) {
      return this.initiateChunkedUpload(params);
    }
    
    // For smaller files, use regular upload
    const url = `/courses/admin/courses/${params.courseId}/lectures/upload/`;
    const form = new FormData();
    form.append('title', params.title);
    if (params.description) form.append('description', params.description);
    if (params.file) form.append('file', params.file);
    const res = await this.axiosInstance.post(url, form, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 60000, // 60 seconds timeout for regular uploads
    });
    return res.data;
  }
  
  // Method to handle chunked uploads
  private async initiateChunkedUpload(params: { courseId: string; title: string; description?: string; file?: File }): Promise<any> {
    if (!params.file) {
      throw new Error('No file provided for upload');
    }
    
    // Import the chunked uploader dynamically
    const { ChunkedUploader } = await import('../utils/ChunkedUploader');
    
    return new Promise((resolve, reject) => {
      const uploader = new ChunkedUploader(
        (progress) => {
          // Dispatch progress event if needed
          const progressEvent = new CustomEvent('upload-progress', { 
            detail: { 
              progress,
              courseId: params.courseId,
              title: params.title
            } 
          });
          window.dispatchEvent(progressEvent);
        },
        (result) => {
          // Upload completed successfully
          resolve(result);
        },
        (error) => {
          // Upload failed
          reject(new Error(error));
        }
      );
      
      // Generate a lecture ID if not provided
      const lectureId = `lecture_${Date.now()}`;
      
      // Start the upload
      uploader.uploadFile(
        params.file!,
        params.courseId,
        lectureId,
        params.title,
        params.description,
        params.file!.type.startsWith('video/') ? 'video' : 'file'
      );
    });
  }
  
  // Method to upload a single chunk
  async uploadChunk(formData: FormData): Promise<any> {
    try {
      console.log('[CHUNK UPLOAD DEBUG] === STARTING CHUNK UPLOAD ===');
      
      // Log form data fields for debugging
      console.log('[CHUNK UPLOAD DEBUG] FormData fields:');
      for (const pair of (formData as any).entries()) {
        if (pair[0] === 'chunk') {
          console.log(`[CHUNK UPLOAD DEBUG] Field: ${pair[0]}, File: ${pair[1].name}, Size: ${pair[1].size}`);
        } else {
          console.log(`[CHUNK UPLOAD DEBUG] Field: ${pair[0]} = ${pair[1]}`);
        }
      }
      
      // For web uploads, we need to use XMLHttpRequest directly to ensure proper multipart/form-data handling
      // This is because Cloudflare Workers has issues with forwarded multipart/form-data from axios
      console.log('[CHUNK UPLOAD DEBUG] Using XMLHttpRequest for multipart upload');
      
      return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        
        // Set up event handlers
        xhr.onload = function() {
          if (xhr.status >= 200 && xhr.status < 300) {
            const response = JSON.parse(xhr.responseText);
            console.log(`[CHUNK UPLOAD SUCCESS] Upload response status: ${xhr.status}`);
            console.log(`[CHUNK UPLOAD SUCCESS] Upload response data:`, response);
            
            // If this is the final chunk and upload is complete, dispatch a completion event
            if (response.isComplete) {
              console.log('[CHUNK UPLOAD SUCCESS] Final chunk uploaded successfully, dispatching completion event');
              
              // Get the form data entries for the event
              const formDataEntries = Object.fromEntries(formData.entries());
              
              // Dispatch completion event
              const completeEvent = new CustomEvent('upload-complete', {
                detail: {
                  courseId: formDataEntries.courseId as string,
                  title: formDataEntries.title as string,
                  result: response
                }
              });
              window.dispatchEvent(completeEvent);
            }
            
            resolve(response);
          } else {
            console.log(`[CHUNK UPLOAD ERROR] Response status: ${xhr.status}`);
            try {
              const errorData = JSON.parse(xhr.responseText);
              console.log(`[CHUNK UPLOAD ERROR] Response data:`, errorData);
              reject(new Error(errorData.error || 'Upload failed'));
            } catch (e) {
              reject(new Error(`Upload failed with status ${xhr.status}`));
            }
          }
        };
        
        xhr.onerror = function() {
          console.log('[CHUNK UPLOAD ERROR] Network error occurred');
          reject(new Error('Network error occurred during upload'));
        };
        
        xhr.ontimeout = function() {
          console.log('[CHUNK UPLOAD ERROR] Upload timed out');
          reject(new Error('Upload timed out'));
        };
        
        xhr.upload.onprogress = function(event) {
          if (event.lengthComputable) {
            const percentComplete = Math.round((event.loaded / event.total) * 100);
            console.log(`[CHUNK UPLOAD PROGRESS] ${percentComplete}%`);
            
            // Dispatch progress event for the progress bar component
            const formDataEntries = Object.fromEntries(formData.entries());
            const progressEvent = new CustomEvent('upload-progress', { 
              detail: { 
                progress: {
                  chunkIndex: parseInt(formDataEntries.chunkIndex as string),
                  totalChunks: parseInt(formDataEntries.totalChunks as string),
                  percentage: percentComplete,
                  completed: event.loaded,
                  total: event.total,
                  isComplete: percentComplete === 100,
                  uploadSessionId: formDataEntries.uploadSessionId as string
                },
                courseId: formDataEntries.courseId as string,
                title: formDataEntries.title as string
              } 
            });
            window.dispatchEvent(progressEvent);
          }
        };
        
        // Open the request - use the full URL including the API base
        const token = localStorage.getItem('access_token');
        const baseUrl = 'https://lms-api-production.muheet228.workers.dev/api';
        xhr.open('POST', `${baseUrl}/admin/upload-chunk`, true);
        
        // Set the authorization header
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        
        // Set timeout - increased to handle server-side processing time after upload
        xhr.timeout = 600000; // 10 minutes
        
        // Send the FormData
        xhr.send(formData);
      });
    } catch (error: any) {
      console.log('[CHUNK UPLOAD ERROR] === UPLOAD ERROR DETAILS ===');
      console.log(`[CHUNK UPLOAD ERROR] Error message: ${error.message}`);
      
      if (error.response) {
        console.log(`[CHUNK UPLOAD ERROR] Response status: ${error.response.status}`);
        console.log(`[CHUNK UPLOAD ERROR] Response data: ${JSON.stringify(error.response.data)}`);
      } else {
        console.log('[CHUNK UPLOAD ERROR] No response received (connection error or timeout)');
      }
      
      throw error;
    }
  }

  async getAvailableTeachers(): Promise<{ instructors: Array<{ _id: string; first_name: string; last_name: string; email: string }> }> {
    const res = await this.axiosInstance.get('/admin/instructors');
    const raw = res.data?.instructors ?? [];
    const normalized = (Array.isArray(raw) ? raw : []).map((t: any) => {
      const id = t?._id || t?.id || '';
      const email = t?.email || '';
      let first = t?.first_name;
      let last = t?.last_name;
      if (!first || !last) {
        const name: string = t?.name || '';
        const parts = name.trim().split(/\s+/);
        first = first || (parts[0] || '');
        last = last || (parts.slice(1).join(' ') || '');
      }
      return { _id: String(id), first_name: String(first || ''), last_name: String(last || ''), email: String(email) };
    });
    return { instructors: normalized };
  }

  async getAdminCourses(): Promise<{ courses: Array<{ _id: string; title: string; description: string; category: string; level: string; price: number; instructor_name?: string; created_at?: string; status?: string; }> }> {
    const res = await this.axiosInstance.get('/admin/courses');
    return res.data;
  }

  async login(email: string, password: string): Promise<{ user: UserProfile; token: string }> {
    try {
      const response: AxiosResponse<LoginResponse> = await this.axiosInstance.post('/auth/login', {
        email,
        password,
      });

      if (response.data.success) {
        const userData = response.data.user;
        return {
          user: {
            id: userData.id,
            email: userData.email,
            firstName: userData.first_name,
            lastName: userData.last_name,
            role: userData.role,
            name: `${userData.first_name} ${userData.last_name}`.trim(),
          },
          token: response.data.token,
        };
      } else {
        const apiError = ErrorHandler.parseError({ response: { status: 400, data: { message: response.data.message } } });
        throw new Error(apiError.message);
      }
    } catch (error: any) {
      const apiError = ErrorHandler.parseError(error);
      throw new Error(apiError.message);
    }
  }

  async register(userData: {
    email: string;
    password: string;
    confirmPassword: string;
    firstName: string;
    lastName: string;
    role: string;
  }): Promise<{ user: UserProfile; token?: string }> {
    try {
      const response: AxiosResponse<RegisterResponse> = await this.axiosInstance.post('/auth/register', {
        email: userData.email,
        password: userData.password,
        confirm_password: userData.confirmPassword,
        first_name: userData.firstName,
        last_name: userData.lastName,
        role: userData.role,
      });

      if (response.data.success) {
        const user = response.data.user;
        return {
          user: {
            id: user.id,
            email: user.email,
            firstName: user.first_name,
            lastName: user.last_name,
            role: user.role,
            name: `${user.first_name} ${user.last_name}`.trim(),
          },
          token: response.data.tokens?.access,
        };
      } else {
        const apiError = ErrorHandler.parseError({ response: { status: 400, data: { message: response.data.message } } });
        throw new Error(apiError.message);
      }
    } catch (error: any) {
      const apiError = ErrorHandler.parseError(error);
      throw new Error(apiError.message);
    }
  }

  async getProfile(): Promise<UserProfile> {
    try {
      const response = await this.axiosInstance.get('/auth/profile');
      const userData = response.data.user || response.data;
      
      return {
        id: userData.id,
        email: userData.email,
        firstName: userData.first_name || userData.firstName,
        lastName: userData.last_name || userData.lastName,
        role: userData.role,
        name: `${userData.first_name || userData.firstName} ${userData.last_name || userData.lastName}`.trim(),
      };
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw new Error(error.message || 'Failed to fetch profile');
    }
  }

  async checkPasswordStrength(password: string): Promise<{ strength: number; feedback: string[]; is_valid: boolean }> {
    try {
      const response = await this.axiosInstance.post('/auth/check-password-strength', { password });
      const data = response.data || {};

      // Normalize backend response (backend returns: { success, strength: 0..5, feedback: string[] })
      const strengthFromApi = typeof data.strength === 'number' ? data.strength : 0;
      const feedbackFromApi = Array.isArray(data.feedback) ? data.feedback : [];
      // Valid only when all 5 checks pass (matches our basicPasswordValidation logic)
      const isValidFromApi = data.is_valid === true ? true : strengthFromApi >= 5;

      return { strength: strengthFromApi, feedback: feedbackFromApi, is_valid: isValidFromApi };
    } catch (error: any) {
      // Fallback to basic validation if API fails
      return this.basicPasswordValidation(password);
    }
  }

  // Edit user name
  async editUserName(firstName: string, lastName: string): Promise<{ success: boolean; message: string; user?: { first_name: string; last_name: string } }> {
    try {
      const response = await this.axiosInstance.put('/user/edit-name', {
        first_name: firstName,
        last_name: lastName
      });
      return response.data;
    } catch (error: any) {
      throw new Error(error.response?.data?.error || 'Failed to update name');
    }
  }

  // Forgot password functionality
  async forgotPassword(email: string): Promise<{ success: boolean; message: string; reset_code?: string }> {
    try {
      const response = await this.axiosInstance.post('/auth/forgot-password', {
        email
      });
      return response.data;
    } catch (error: any) {
      throw new Error(error.response?.data?.error || 'Failed to send reset code');
    }
  }

  async verifyResetCode(email: string, code: string): Promise<{ success: boolean; message: string; verified: boolean }> {
    try {
      const response = await this.axiosInstance.post('/auth/verify-reset-code', {
        email,
        code
      });
      return response.data;
    } catch (error: any) {
      throw new Error(error.response?.data?.error || 'Failed to verify reset code');
    }
  }

  async resetPassword(email: string, code: string, newPassword: string, confirmPassword: string): Promise<{ success: boolean; message: string }> {
    try {
      const response = await this.axiosInstance.post('/auth/reset-password', {
        email,
        code,
        new_password: newPassword,
        confirm_password: confirmPassword
      });
      return response.data;
    } catch (error: any) {
      throw new Error(error.response?.data?.error || 'Failed to reset password');
    }
  }

  private basicPasswordValidation(password: string): { strength: number; feedback: string[]; is_valid: boolean } {
    const hasUpper = /[A-Z]/.test(password);
    const hasLower = /[a-z]/.test(password);
    const hasDigit = /[0-9]/.test(password);
    const hasSpecial = /[!@#$%^&*(),.?":{}|<>]/.test(password);

    let strength = 0;
    let feedback: string[] = [];
    let isValid = false;

    if (password.length < 8) {
      strength = 0;
      feedback = ['Password must be at least 8 characters long'];
      isValid = false;
    } else if (!hasUpper || !hasLower) {
      strength = 1;
      feedback = ['Password must contain both uppercase and lowercase letters'];
      isValid = false;
    } else if (!hasDigit) {
      strength = 2;
      feedback = ['Password must contain at least one number'];
      isValid = false;
    } else if (!hasSpecial) {
      strength = 3;
      feedback = ['Good! Add special characters for stronger password'];
      isValid = false;
    } else {
      strength = 5;
      feedback = ['Excellent! Strong password'];
      isValid = true;
    }

    return { strength, feedback, is_valid: isValid };
  }
}

export const apiService = new ApiService();
