import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useDarkMode } from '../contexts/DarkModeContext';
import { Mail, Lock, Eye, EyeOff, BookOpen } from 'lucide-react';
import DarkModeToggle from '../components/DarkModeToggle';
import './LoginPage.css';

const LoginPage: React.FC = () => {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
  });
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);

  const { login, loading, error, fieldErrors, clearError, clearFieldError, isAuthenticated } = useAuth();
  const { isDarkMode } = useDarkMode();
  const navigate = useNavigate();

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      navigate('/dashboard');
    }
  }, [isAuthenticated, navigate]);


  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value,
    }));
    
    // Clear errors when user starts typing
    if (error) {
      clearError();
    }
    if (fieldErrors[name]) {
      clearFieldError(name);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.email || !formData.password) {
      return;
    }

    try {
      await login(formData.email, formData.password);
      navigate('/dashboard');
    } catch (error) {
      // Error is handled by the auth context
    }
  };

  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  return (
    <div className={`login-page ${isDarkMode ? 'dark' : ''}`}>
      {/* Navigation Header */}
      <nav className="navbar">
        <div className="nav-container">
          <div className="nav-brand">
            <div className="brand-logo">
              <BookOpen className="logo-icon" />
            </div>
            <span className="brand-name">LMS</span>
          </div>
          <div className="nav-actions">
            <DarkModeToggle size="medium" />
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <div className="login-main">
        <div className="login-container">
          {/* Left Side - Branding */}
          <div className="login-hero">
            <div className="hero-content">
              <h1 className="hero-title">Welcome to LMS</h1>
              <p className="hero-subtitle">
                Your comprehensive learning management system. Access courses, 
                track progress, and connect with educators worldwide.
              </p>
              <div className="hero-features">
                <div className="feature-item">
                  <div className="feature-icon">📚</div>
                  <span>Interactive Courses</span>
                </div>
                <div className="feature-item">
                  <div className="feature-icon">🎓</div>
                  <span>Expert Instructors</span>
                </div>
                <div className="feature-item">
                  <div className="feature-icon">📱</div>
                  <span>Mobile & Web Access</span>
                </div>
              </div>
            </div>
          </div>

          {/* Right Side - Login Form */}
          <div className="login-form-section">
            <div className="login-card">
              {/* Form Header */}
              <div className="form-header">
                <h2 className="form-title">Sign In</h2>
                <p className="form-subtitle">Welcome back! Please sign in to your account</p>
              </div>

              {/* Error Message */}
              {error && (
                <div className="error-message">
                  <div className="error-icon">⚠️</div>
                  <div className="error-text">{error}</div>
                  <button 
                    className="error-close"
                    onClick={clearError}
                    aria-label="Close error"
                  >
                    ✕
                  </button>
                </div>
              )}

              {/* Login Form */}
              <form onSubmit={handleSubmit} className="login-form">
              {/* Email Field */}
              <div className="form-group">
                <div className="input-container">
                  <Mail className="input-icon" />
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleInputChange}
                    placeholder="Enter your email"
                    className={`form-input ${fieldErrors.email ? 'error' : ''}`}
                    required
                  />
                </div>
                {fieldErrors.email && (
                  <div className="field-error">{fieldErrors.email}</div>
                )}
              </div>

              {/* Password Field */}
              <div className="form-group">
                <div className="input-container">
                  <Lock className="input-icon" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    name="password"
                    value={formData.password}
                    onChange={handleInputChange}
                    placeholder="Enter your password"
                    className={`form-input ${fieldErrors.password ? 'error' : ''}`}
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle"
                    onClick={togglePasswordVisibility}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff /> : <Eye />}
                  </button>
                </div>
                {fieldErrors.password && (
                  <div className="field-error">{fieldErrors.password}</div>
                )}
              </div>

              {/* Remember Me & Forgot Password */}
              <div className="form-options">
                <label className="checkbox-container">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                  />
                  <span className="checkmark"></span>
                  Remember me
                </label>
                <Link to="/forgot-password" className="forgot-password">
                  Forgot Password?
                </Link>
              </div>

              {/* Login Button */}
              <button
                type="submit"
                className="btn btn-primary login-button"
                disabled={loading || !formData.email || !formData.password}
              >
                {loading ? (
                  <div className="loading-spinner"></div>
                ) : (
                  'Sign In'
                )}
              </button>

              {/* Divider */}
              <div className="divider">
                <div className="divider-line"></div>
                <span className="divider-text">OR</span>
                <div className="divider-line"></div>
              </div>

              {/* Social Login Buttons */}
              <div className="social-login">
                <button type="button" className="btn btn-outline social-button">
                  <span className="social-icon">G</span>
                  Google
                </button>
                <button type="button" className="btn btn-outline social-button">
                  <span className="social-icon">f</span>
                  Facebook
                </button>
              </div>

              {/* Sign Up Link */}
              <div className="signup-link">
                <span>Don't have an account? </span>
                <Link to="/register" className="btn-link">
                  Sign Up
                </Link>
              </div>
              </form>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="login-footer">
        <div className="footer-content">
          <p>&copy; 2024 LMS. All rights reserved.</p>
          <div className="footer-links">
            <a href="#">Privacy Policy</a>
            <a href="#">Terms of Service</a>
            <a href="#">Contact</a>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default LoginPage;
