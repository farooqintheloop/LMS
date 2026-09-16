import React, { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { apiService } from '../services/apiService';

interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  name: string;
}

interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  token: string | null;
  loading: boolean;
  error: string | null;
  fieldErrors: Record<string, string>;
}

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  register: (userData: RegisterData) => Promise<void>;
  logout: () => void;
  clearError: () => void;
  clearFieldError: (field: string) => void;
  updateUser: (firstName: string, lastName: string) => void;
}

interface RegisterData {
  email: string;
  password: string;
  confirmPassword: string;
  firstName: string;
  lastName: string;
  role: string;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [state, setState] = useState<AuthState>({
    isAuthenticated: false,
    user: null,
    token: null,
    loading: true,
    error: null,
    fieldErrors: {},
  });

  // Check for existing token on mount
  useEffect(() => {
    const checkAuth = async () => {
      const path = window.location.pathname;
      // Do not auto-authenticate on login/register routes; stay on login first
      if (path === '/login' || path === '/register') {
        setState(prev => ({ ...prev, loading: false }));
        return;
      }
      try {
        const token = localStorage.getItem('access_token');
        if (token) {
          // Verify token with backend
          const userData = await apiService.getProfile();
          setState({
            isAuthenticated: true,
            user: userData,
            token,
            loading: false,
            error: null,
            fieldErrors: {},
          });
        } else {
          setState(prev => ({ ...prev, loading: false }));
        }
      } catch (error) {
        // Token is invalid, clear it
        localStorage.removeItem('access_token');
        setState(prev => ({ ...prev, loading: false }));
      }
    };

    checkAuth();
  }, []);

  const login = async (email: string, password: string) => {
    setState(prev => ({ ...prev, loading: true, error: null, fieldErrors: {} }));
    
    try {
      const response = await apiService.login(email, password);
      
      setState({
        isAuthenticated: true,
        user: response.user,
        token: response.token,
        loading: false,
        error: null,
        fieldErrors: {},
      });
      
      localStorage.setItem('access_token', response.token);
    } catch (error: any) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Login failed',
        fieldErrors: {},
      }));
      throw error;
    }
  };

  const register = async (userData: RegisterData) => {
    setState(prev => ({ ...prev, loading: true, error: null, fieldErrors: {} }));
    
    try {
      await apiService.register(userData);
      
      // After successful registration, automatically log in
      await login(userData.email, userData.password);
    } catch (error: any) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Registration failed',
        fieldErrors: {},
      }));
      throw error;
    }
  };

  const logout = () => {
    localStorage.removeItem('access_token');
    setState({
      isAuthenticated: false,
      user: null,
      token: null,
      loading: false,
      error: null,
      fieldErrors: {},
    });
  };

  const clearError = () => {
    setState(prev => ({ ...prev, error: null, fieldErrors: {} }));
  };

  const clearFieldError = (field: string) => {
    setState(prev => ({
      ...prev,
      fieldErrors: { ...prev.fieldErrors, [field]: '' }
    }));
  };

  const updateUser = (firstName: string, lastName: string) => {
    setState(prev => ({
      ...prev,
      user: prev.user ? {
        ...prev.user,
        firstName,
        lastName,
        name: `${firstName} ${lastName}`
      } : null
    }));
  };

  const value: AuthContextType = {
    ...state,
    login,
    register,
    logout,
    clearError,
    clearFieldError,
    updateUser,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
