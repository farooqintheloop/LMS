// Error handling utilities for better user experience

export interface ApiError {
  message: string;
  type: 'validation' | 'authentication' | 'authorization' | 'network' | 'server' | 'unknown';
  field?: string;
}

export class ErrorHandler {
  static parseError(error: any): ApiError {
    // Network errors
    if (!error.response) {
      if (error.code === 'ECONNABORTED' || error.message?.includes('timeout')) {
        return {
          message: 'Connection timeout. Please check your internet connection and try again.',
          type: 'network'
        };
      }
      if (error.message?.includes('Network Error')) {
        return {
          message: 'Network error. Please check your internet connection and try again.',
          type: 'network'
        };
      }
      return {
        message: 'Unable to connect to the server. Please try again later.',
        type: 'network'
      };
    }

    const status = error.response.status;
    const data = error.response.data;

    // Authentication errors
    if (status === 401) {
      if (data.message?.toLowerCase().includes('invalid credentials')) {
        return {
          message: 'Invalid email or password. Please check your credentials and try again.',
          type: 'authentication'
        };
      }
      if (data.message?.toLowerCase().includes('user not found')) {
        return {
          message: 'No account found with this email address. Please check your email or sign up.',
          type: 'authentication'
        };
      }
      if (data.message?.toLowerCase().includes('password')) {
        return {
          message: 'Incorrect password. Please try again.',
          type: 'authentication'
        };
      }
      return {
        message: 'Authentication failed. Please check your credentials.',
        type: 'authentication'
      };
    }

    // Authorization errors
    if (status === 403) {
      return {
        message: 'You do not have permission to perform this action.',
        type: 'authorization'
      };
    }

    // Validation errors
    if (status === 400) {
      const message = data.message || 'Invalid input provided.';
      
      // Check for specific validation errors
      if (message.toLowerCase().includes('email')) {
        return {
          message: 'Please enter a valid email address.',
          type: 'validation',
          field: 'email'
        };
      }
      if (message.toLowerCase().includes('password')) {
        return {
          message: 'Password must be at least 6 characters long.',
          type: 'validation',
          field: 'password'
        };
      }
      if (message.toLowerCase().includes('name')) {
        return {
          message: 'Please enter a valid name.',
          type: 'validation',
          field: 'name'
        };
      }
      if (message.toLowerCase().includes('already exists') || message.toLowerCase().includes('already registered')) {
        return {
          message: 'An account with this email already exists. Please use a different email or try logging in.',
          type: 'validation',
          field: 'email'
        };
      }
      if (message.toLowerCase().includes('password') && message.toLowerCase().includes('match')) {
        return {
          message: 'Passwords do not match. Please try again.',
          type: 'validation',
          field: 'confirmPassword'
        };
      }
      
      return {
        message: message,
        type: 'validation'
      };
    }

    // Server errors
    if (status >= 500) {
      return {
        message: 'Server error. Please try again later.',
        type: 'server'
      };
    }

    // Default error
    return {
      message: data.message || 'An unexpected error occurred. Please try again.',
      type: 'unknown'
    };
  }

  static getErrorMessage(error: ApiError): string {
    return error.message;
  }

  static getErrorType(error: ApiError): string {
    return error.type;
  }

  static getErrorField(error: ApiError): string | undefined {
    return error.field;
  }
}
