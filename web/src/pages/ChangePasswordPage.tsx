import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Key, Lock, Shield, Mail, CheckCircle, AlertCircle, Eye, EyeOff, Clock } from 'lucide-react';
import DarkModeToggle from '../components/DarkModeToggle';
import './ChangePasswordPage.css';
import { apiService } from '../services/apiService';

type Step = 'forgot' | 'verify' | 'reset' | 'success';

const ChangePasswordPage: React.FC = () => {
  const { isAuthenticated, user } = useAuth();
  const navigate = useNavigate();
  
  // State management
  const [currentStep, setCurrentStep] = useState<Step>('forgot');
  const [email, setEmail] = useState('');
  const [resetCode, setResetCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [timeLeft, setTimeLeft] = useState(0);
  const [passwordStrength, setPasswordStrength] = useState<{ strength: number; feedback: string[]; is_valid: boolean }>({ strength: 0, feedback: [], is_valid: false });

  // Redirect to login if not authenticated
  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  // Set user email if available
  useEffect(() => {
    if (user?.email) {
      setEmail(user.email);
    }
  }, [user]);

  // Timer for reset code expiry
  useEffect(() => {
    if (timeLeft > 0) {
      const timer = setTimeout(() => setTimeLeft(timeLeft - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [timeLeft]);

  // Password strength validation
  useEffect(() => {
    if (newPassword) {
      apiService.checkPasswordStrength(newPassword).then(setPasswordStrength);
    }
  }, [newPassword]);

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const response = await apiService.forgotPassword(email);
      if (response.success) {
        setSuccess('Reset code sent to your email address');
        setCurrentStep('verify');
        setTimeLeft(600); // 10 minutes
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyCode = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await apiService.verifyResetCode(email, resetCode);
      if (response.success) {
        setSuccess('Code verified successfully');
        setCurrentStep('reset');
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      setLoading(false);
      return;
    }

    if (!passwordStrength.is_valid) {
      setError('Password does not meet strength requirements');
      setLoading(false);
      return;
    }

    try {
      const response = await apiService.resetPassword(email, resetCode, newPassword, confirmPassword);
      if (response.success) {
        setSuccess('Password reset successfully');
        setCurrentStep('success');
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleBackToDashboard = () => {
    navigate('/dashboard');
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const getStrengthColor = (strength: number) => {
    if (strength <= 1) return '#ff4444';
    if (strength <= 2) return '#ff8800';
    if (strength <= 3) return '#ffbb00';
    if (strength <= 4) return '#88cc00';
    return '#00cc44';
  };

  const getStrengthText = (strength: number) => {
    if (strength <= 1) return 'Very Weak';
    if (strength <= 2) return 'Weak';
    if (strength <= 3) return 'Fair';
    if (strength <= 4) return 'Good';
    return 'Strong';
  };

  return (
    <div className="change-password-page">
      {/* Navigation Header */}
      <nav className="navbar">
        <div className="nav-container">
          <div className="nav-brand">
            <div className="brand-logo">
              <Key className="logo-icon" />
            </div>
            <span className="brand-name">LMS</span>
          </div>
          <div className="nav-actions">
            <button className="back-button" onClick={handleBackToDashboard}>
              <ArrowLeft size={20} />
              Back to Dashboard
            </button>
            <DarkModeToggle size="medium" />
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="change-password-main">
        <div className="change-password-container">
          {/* Header Section */}
          <div className="page-header">
            <div className="header-icon">
              <Shield className="icon" />
            </div>
            <h1 className="page-title">Change Password</h1>
            <p className="page-subtitle">Secure your account with a new password</p>
          </div>

          {/* Progress Steps */}
          <div className="progress-steps">
            <div className={`step ${currentStep === 'forgot' ? 'active' : currentStep === 'verify' || currentStep === 'reset' || currentStep === 'success' ? 'completed' : ''}`}>
              <div className="step-number">1</div>
              <div className="step-label">Enter Email</div>
            </div>
            <div className={`step ${currentStep === 'verify' ? 'active' : currentStep === 'reset' || currentStep === 'success' ? 'completed' : ''}`}>
              <div className="step-number">2</div>
              <div className="step-label">Verify Code</div>
            </div>
            <div className={`step ${currentStep === 'reset' ? 'active' : currentStep === 'success' ? 'completed' : ''}`}>
              <div className="step-number">3</div>
              <div className="step-label">New Password</div>
            </div>
            <div className={`step ${currentStep === 'success' ? 'active' : ''}`}>
              <div className="step-number">4</div>
              <div className="step-label">Complete</div>
            </div>
          </div>

          {/* Step 1: Forgot Password */}
          {currentStep === 'forgot' && (
            <div className="step-content">
              <div className="step-header">
                <Mail className="step-icon" />
                <h2>Enter Your Email</h2>
                <p>We'll send a 6-digit verification code to your email address</p>
              </div>
              
              <form onSubmit={handleForgotPassword} className="form">
                <div className="form-group">
                  <label htmlFor="email">Email Address</label>
                  <input
                    type="email"
                    id="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Enter your email address"
                    required
                    disabled={loading}
                  />
                </div>

                {error && (
                  <div className="error-message">
                    <AlertCircle size={16} />
                    {error}
                  </div>
                )}

                {success && (
                  <div className="success-message">
                    <CheckCircle size={16} />
                    {success}
                  </div>
                )}

                <button type="submit" className="btn btn-primary" disabled={loading}>
                  {loading ? 'Sending...' : 'Send Reset Code'}
                </button>
              </form>
            </div>
          )}

          {/* Step 2: Verify Code */}
          {currentStep === 'verify' && (
            <div className="step-content">
              <div className="step-header">
                <Key className="step-icon" />
                <h2>Enter Verification Code</h2>
                <p>Check your email for the 6-digit code</p>
                {timeLeft > 0 && (
                  <div className="timer">
                    <Clock size={16} />
                    Code expires in: {formatTime(timeLeft)}
                  </div>
                )}
              </div>
              
              <form onSubmit={handleVerifyCode} className="form">
                <div className="form-group">
                  <label htmlFor="code">Verification Code</label>
                  <input
                    type="text"
                    id="code"
                    value={resetCode}
                    onChange={(e) => setResetCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    placeholder="Enter 6-digit code"
                    maxLength={6}
                    required
                    disabled={loading}
                    className="code-input"
                  />
                </div>

                {error && (
                  <div className="error-message">
                    <AlertCircle size={16} />
                    {error}
                  </div>
                )}

                {success && (
                  <div className="success-message">
                    <CheckCircle size={16} />
                    {success}
                  </div>
                )}

                <div className="form-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setCurrentStep('forgot')}>
                    Back
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={loading || resetCode.length !== 6}>
                    {loading ? 'Verifying...' : 'Verify Code'}
                  </button>
                </div>
              </form>
            </div>
          )}

          {/* Step 3: Reset Password */}
          {currentStep === 'reset' && (
            <div className="step-content">
              <div className="step-header">
                <Lock className="step-icon" />
                <h2>Create New Password</h2>
                <p>Choose a strong password for your account</p>
              </div>
              
              <form onSubmit={handleResetPassword} className="form">
                <div className="form-group">
                  <label htmlFor="newPassword">New Password</label>
                  <div className="password-input-container">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      id="newPassword"
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      placeholder="Enter new password"
                      required
                      disabled={loading}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                  
                  {newPassword && (
                    <div className="password-strength">
                      <div className="strength-bar">
                        <div 
                          className="strength-fill" 
                          style={{ 
                            width: `${(passwordStrength.strength / 5) * 100}%`,
                            backgroundColor: getStrengthColor(passwordStrength.strength)
                          }}
                        />
                      </div>
                      <div className="strength-text" style={{ color: getStrengthColor(passwordStrength.strength) }}>
                        {getStrengthText(passwordStrength.strength)}
                      </div>
                    </div>
                  )}
                  
                  {passwordStrength.feedback.length > 0 && (
                    <div className="password-feedback">
                      {passwordStrength.feedback.map((feedback, index) => (
                        <div key={index} className={`feedback-item ${passwordStrength.is_valid ? 'valid' : 'invalid'}`}>
                          {passwordStrength.is_valid ? <CheckCircle size={12} /> : <AlertCircle size={12} />}
                          {feedback}
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="form-group">
                  <label htmlFor="confirmPassword">Confirm Password</label>
                  <div className="password-input-container">
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      id="confirmPassword"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Confirm new password"
                      required
                      disabled={loading}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    >
                      {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                {error && (
                  <div className="error-message">
                    <AlertCircle size={16} />
                    {error}
                  </div>
                )}

                {success && (
                  <div className="success-message">
                    <CheckCircle size={16} />
                    {success}
                  </div>
                )}

                <div className="form-actions">
                  <button type="button" className="btn btn-secondary" onClick={() => setCurrentStep('verify')}>
                    Back
                  </button>
                  <button 
                    type="submit" 
                    className="btn btn-primary" 
                    disabled={loading || !passwordStrength.is_valid || newPassword !== confirmPassword}
                  >
                    {loading ? 'Resetting...' : 'Reset Password'}
                  </button>
                </div>
              </form>
            </div>
          )}

          {/* Step 4: Success */}
          {currentStep === 'success' && (
            <div className="step-content success-content">
              <div className="success-icon">
                <CheckCircle size={64} />
              </div>
              <h2>Password Reset Successful!</h2>
              <p>Your password has been updated successfully. You can now log in with your new password.</p>
              
              <div className="success-actions">
                <button className="btn btn-primary" onClick={handleBackToDashboard}>
                  Return to Dashboard
                </button>
                <button className="btn btn-secondary" onClick={() => navigate('/login')}>
                  Go to Login
                </button>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="footer">
        <div className="footer-content">
          <div className="footer-section">
            <h4>Security</h4>
            <p>Your account security is our priority</p>
          </div>
          <div className="footer-section">
            <h4>Support</h4>
            <p>Need help? Contact our support team</p>
          </div>
          <div className="footer-section">
            <h4>Privacy</h4>
            <p>We protect your personal information</p>
          </div>
        </div>
        <div className="footer-bottom">
          <p>&copy; 2024 LMS. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default ChangePasswordPage;