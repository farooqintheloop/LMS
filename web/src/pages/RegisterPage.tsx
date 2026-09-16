import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useDarkMode } from '../contexts/DarkModeContext';
import { apiService } from '../services/apiService';
import { Mail, Lock, User, Eye, EyeOff, BookOpen, ArrowLeft, GraduationCap, Users } from 'lucide-react';
import DarkModeToggle from '../components/DarkModeToggle';
import './RegisterPage.css';

const RegisterPage: React.FC = () => {
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [selectedRole, setSelectedRole] = useState('student');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [agreeToTerms, setAgreeToTerms] = useState(false);
  const [passwordStrength, setPasswordStrength] = useState(0);
  const [passwordFeedback, setPasswordFeedback] = useState('');
  const [isPasswordValid, setIsPasswordValid] = useState(false);

  const { register, loading, error, fieldErrors, clearError, clearFieldError, isAuthenticated } = useAuth();
  const { isDarkMode } = useDarkMode();
  const navigate = useNavigate();

  const roles = [
    {
      value: 'student',
      label: 'Student',
      icon: GraduationCap,
      description: 'Learn and grow with our courses'
    },
    {
      value: 'teacher',
      label: 'Teacher',
      icon: Users,
      description: 'Share your knowledge and expertise'
    },
  ];

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

    // Check password strength when password changes
    if (name === 'password') {
      checkPasswordStrength(value);
    }
  };

  const checkPasswordStrength = async (password: string) => {
    if (!password) {
      setPasswordStrength(0);
      setPasswordFeedback('');
      setIsPasswordValid(false);
      return;
    }

    try {
      const result = await apiService.checkPasswordStrength(password);
      setPasswordStrength(result.strength / 5); // Convert to 0-1 scale
      setPasswordFeedback(result.feedback[0] || '');
      setIsPasswordValid(result.is_valid);
    } catch (error) {
      // Fallback to basic validation
      const hasUpper = /[A-Z]/.test(password);
      const hasLower = /[a-z]/.test(password);
      const hasDigit = /[0-9]/.test(password);
      const hasSpecial = /[!@#$%^&*(),.?":{}|<>]/.test(password);

      let strength = 0;
      let feedback = '';
      let isValid = false;

      if (password.length < 8) {
        strength = 0;
        feedback = 'Password must be at least 8 characters long';
        isValid = false;
      } else if (!hasUpper || !hasLower) {
        strength = 0.2;
        feedback = 'Password must contain both uppercase and lowercase letters';
        isValid = false;
      } else if (!hasDigit) {
        strength = 0.4;
        feedback = 'Password must contain at least one number';
        isValid = false;
      } else if (!hasSpecial) {
        strength = 0.6;
        feedback = 'Good! Add special characters for stronger password';
        isValid = false;
      } else {
        strength = 1.0;
        feedback = 'Excellent! Strong password';
        isValid = true;
      }

      setPasswordStrength(strength);
      setPasswordFeedback(feedback);
      setIsPasswordValid(isValid);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.firstName || !formData.lastName || !formData.email || !formData.password || !formData.confirmPassword) {
      return;
    }

    if (formData.password !== formData.confirmPassword) {
      return;
    }

    if (!agreeToTerms) {
      return;
    }

    try {
      await register({
        firstName: formData.firstName,
        lastName: formData.lastName,
        email: formData.email,
        password: formData.password,
        confirmPassword: formData.confirmPassword,
        role: selectedRole,
      });
      navigate('/dashboard');
    } catch (error) {
      // Error is handled by the auth context
    }
  };

  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  const toggleConfirmPasswordVisibility = () => {
    setShowConfirmPassword(!showConfirmPassword);
  };


  const getPasswordStrengthColor = () => {
    if (passwordStrength >= 0.8) return '#28a745'; // Green
    if (passwordStrength >= 0.6) return '#ffc107'; // Yellow
    return '#dc3545'; // Red
  };

  const getPasswordStrengthText = () => {
    if (passwordStrength >= 0.8) return 'Strong';
    if (passwordStrength >= 0.6) return 'Medium';
    if (passwordStrength >= 0.4) return 'Weak';
    return 'Weak';
  };

  return (
    <div className={`register-page ${isDarkMode ? 'dark' : ''}`}>
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
            <Link to="/login" className="back-link">
              <ArrowLeft size={20} />
              Back to Login
            </Link>
            <DarkModeToggle size="medium" />
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <div className="register-main">
        <div className="register-container">
          {/* Left Side - Branding */}
          <div className="register-hero">
            <div className="hero-content">
              <h1 className="hero-title">Join Our Learning Community</h1>
              <p className="hero-subtitle">
                Start your educational journey with access to thousands of courses, 
                expert instructors, and a supportive learning environment.
              </p>
              <div className="hero-stats">
                <div className="stat-item">
                  <div className="stat-number">10K+</div>
                  <div className="stat-label">Students</div>
                </div>
                <div className="stat-item">
                  <div className="stat-number">500+</div>
                  <div className="stat-label">Courses</div>
                </div>
                <div className="stat-item">
                  <div className="stat-number">50+</div>
                  <div className="stat-label">Instructors</div>
                </div>
              </div>
            </div>
          </div>

          {/* Right Side - Registration Form */}
          <div className="register-form-section">
            <div className="register-card">
              {/* Form Header */}
              <div className="form-header">
                <h2 className="form-title">Create Account</h2>
                <p className="form-subtitle">Join our learning community today</p>
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

            {/* Register Form */}
            <form onSubmit={handleSubmit} className="register-form">
              {/* Role Selection */}
              <div className="role-selection">
                <label className="role-label">I am a:</label>
                <div className="role-options">
                  {roles.map((role) => {
                    const IconComponent = role.icon;
                    const isSelected = selectedRole === role.value;
                    return (
                      <div
                        key={role.value}
                        className={`role-option ${isSelected ? 'selected' : ''}`}
                        onClick={() => setSelectedRole(role.value)}
                      >
                        <IconComponent className="role-icon" />
                        <div className="role-info">
                          <div className="role-name">{role.label}</div>
                          <div className="role-description">{role.description}</div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Name Fields */}
              <div className="name-fields">
                <div className="form-group">
                  <div className="input-container">
                    <User className="input-icon" />
                    <input
                      type="text"
                      name="firstName"
                      value={formData.firstName}
                      onChange={handleInputChange}
                      placeholder="First name"
                      className={`form-input ${fieldErrors.firstName ? 'error' : ''}`}
                      required
                    />
                  </div>
                  {fieldErrors.firstName && (
                    <div className="field-error">{fieldErrors.firstName}</div>
                  )}
                </div>
                <div className="form-group">
                  <div className="input-container">
                    <User className="input-icon" />
                    <input
                      type="text"
                      name="lastName"
                      value={formData.lastName}
                      onChange={handleInputChange}
                      placeholder="Last name"
                      className={`form-input ${fieldErrors.lastName ? 'error' : ''}`}
                      required
                    />
                  </div>
                  {fieldErrors.lastName && (
                    <div className="field-error">{fieldErrors.lastName}</div>
                  )}
                </div>
              </div>

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
                    placeholder="Create a strong password"
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
                
                {/* Password Strength Indicator */}
                {formData.password && (
                  <div className="password-strength">
                    <div className="strength-bar">
                      <div 
                        className="strength-fill"
                        style={{ 
                          width: `${passwordStrength * 100}%`,
                          backgroundColor: getPasswordStrengthColor()
                        }}
                      ></div>
                    </div>
                    <div className="strength-info">
                      <span 
                        className="strength-text"
                        style={{ color: getPasswordStrengthColor() }}
                      >
                        {getPasswordStrengthText()}
                      </span>
                      {passwordFeedback && (
                        <span 
                          className="strength-feedback"
                          style={{ color: getPasswordStrengthColor() }}
                        >
                          {passwordFeedback}
                        </span>
                      )}
                    </div>
                  </div>
                )}
              </div>

              {/* Confirm Password Field */}
              <div className="form-group">
                <div className="input-container">
                  <Lock className="input-icon" />
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    name="confirmPassword"
                    value={formData.confirmPassword}
                    onChange={handleInputChange}
                    placeholder="Confirm your password"
                    className={`form-input ${fieldErrors.confirmPassword ? 'error' : ''}`}
                    required
                  />
                  <button
                    type="button"
                    className="password-toggle"
                    onClick={toggleConfirmPasswordVisibility}
                    aria-label={showConfirmPassword ? 'Hide password' : 'Show password'}
                  >
                    {showConfirmPassword ? <EyeOff /> : <Eye />}
                  </button>
                </div>
                {fieldErrors.confirmPassword && (
                  <div className="field-error">{fieldErrors.confirmPassword}</div>
                )}
                {formData.confirmPassword && formData.password !== formData.confirmPassword && !fieldErrors.confirmPassword && (
                  <div className="password-mismatch">
                    Passwords do not match
                  </div>
                )}
              </div>

              {/* Terms and Conditions */}
              <div className="terms-container">
                <label className="checkbox-container">
                  <input
                    type="checkbox"
                    checked={agreeToTerms}
                    onChange={(e) => setAgreeToTerms(e.target.checked)}
                    required
                  />
                  <span className="checkmark"></span>
                  <span className="terms-text">
                    I agree to the <a href="#" className="terms-link">Terms of Service</a> and <a href="#" className="terms-link">Privacy Policy</a>
                  </span>
                </label>
              </div>

              {/* Register Button */}
              <button
                type="submit"
                className="btn btn-primary register-button"
                disabled={loading || !isPasswordValid || formData.password !== formData.confirmPassword || !agreeToTerms}
              >
                {loading ? (
                  <div className="loading-spinner"></div>
                ) : (
                  'Create Account'
                )}
              </button>

              {/* Sign In Link */}
              <div className="signin-link">
                <span>Already have an account? </span>
                <Link to="/login" className="btn-link">
                  Sign In
                </Link>
              </div>
              </form>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="register-footer">
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

export default RegisterPage;
