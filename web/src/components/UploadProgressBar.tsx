import React, { useEffect, useState } from 'react';

interface UploadProgressBarProps {
  isVisible: boolean;
  courseId: string;
  title: string;
}

interface ProgressState {
  percentage: number;
  chunkIndex: number;
  totalChunks: number;
  isComplete: boolean;
}

const UploadProgressBar: React.FC<UploadProgressBarProps> = ({ isVisible, courseId, title }) => {
  const [progress, setProgress] = useState<ProgressState>({
    percentage: 0,
    chunkIndex: 0,
    totalChunks: 0,
    isComplete: false,
  });

  useEffect(() => {
    const handleProgress = (event: CustomEvent) => {
      const { progress, courseId: eventCourseId, title: eventTitle } = event.detail;
      
      // Only update if this progress bar is for the same upload
      if (courseId === eventCourseId && title === eventTitle) {
        setProgress({
          percentage: progress.percentage,
          chunkIndex: progress.chunkIndex,
          totalChunks: progress.totalChunks,
          isComplete: progress.isComplete,
        });
      }
    };

    // Add event listener for upload progress
    window.addEventListener('upload-progress', handleProgress as EventListener);

    // Clean up
    return () => {
      window.removeEventListener('upload-progress', handleProgress as EventListener);
    };
  }, [courseId, title]);

  if (!isVisible) return null;

  return (
    <div className="upload-progress-container">
      <div className="upload-progress-header">
        <h4>Uploading: {title}</h4>
        <span className="upload-progress-percentage">{progress.percentage}%</span>
      </div>
      <div className="upload-progress-bar-container">
        <div 
          className="upload-progress-bar" 
          style={{ width: `${progress.percentage}%` }}
        />
      </div>
      <div className="upload-progress-details">
        <span>Chunk {progress.chunkIndex + 1} of {progress.totalChunks}</span>
      </div>
      {/* Styles are in upload.css */}
    </div>
  );
};

export default UploadProgressBar;
