import React from 'react';
import { Sun, Moon } from 'lucide-react';
import { useDarkMode } from '../contexts/DarkModeContext';
import './DarkModeToggle.css';

interface DarkModeToggleProps {
  className?: string;
  size?: 'small' | 'medium' | 'large';
  variant?: 'button' | 'icon';
}

const DarkModeToggle: React.FC<DarkModeToggleProps> = ({ 
  className = '', 
  size = 'medium',
  variant = 'button'
}) => {
  const { isDarkMode, toggleDarkMode } = useDarkMode();

  const sizeClasses = {
    small: 'toggle-small',
    medium: 'toggle-medium',
    large: 'toggle-large'
  };

  const variantClasses = {
    button: 'toggle-button',
    icon: 'toggle-icon'
  };

  return (
    <button
      className={`dark-mode-toggle ${sizeClasses[size]} ${variantClasses[variant]} ${className}`}
      onClick={toggleDarkMode}
      aria-label={isDarkMode ? 'Switch to light mode' : 'Switch to dark mode'}
      title={isDarkMode ? 'Switch to light mode' : 'Switch to dark mode'}
    >
      {isDarkMode ? (
        <Sun className="toggle-icon" size={size === 'small' ? 16 : size === 'large' ? 24 : 20} />
      ) : (
        <Moon className="toggle-icon" size={size === 'small' ? 16 : size === 'large' ? 24 : 20} />
      )}
      {variant === 'button' && (
        <span className="toggle-text">
          {isDarkMode ? 'Light' : 'Dark'}
        </span>
      )}
    </button>
  );
};

export default DarkModeToggle;
