import { apiService } from '../services/apiService';

export interface UploadProgress {
  chunkIndex: number;
  totalChunks: number;
  percentage: number;
  completed: number;
  total: number;
  isComplete: boolean;
  uploadSessionId: string;
}

export interface UploadResult {
  fileInfo: any;
  progress: any;
  uploadSessionId: string;
}

export class ChunkedUploader {
  private onProgress: (progress: UploadProgress) => void;
  private onComplete: (result: UploadResult) => void;
  private onError: (error: string) => void;
  
  // Match the mobile app's chunk size (50MB)
  static readonly CHUNK_SIZE = 50 * 1024 * 1024; // 50MB chunks

  constructor(
    onProgress: (progress: UploadProgress) => void,
    onComplete: (result: UploadResult) => void,
    onError: (error: string) => void,
  ) {
    this.onProgress = onProgress;
    this.onComplete = onComplete;
    this.onError = onError;
  }

  private generateSessionId(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  async uploadFile(
    file: File,
    courseId: string,
    lectureId: string,
    title: string,
    description?: string,
    fileType: string = 'video',
  ): Promise<void> {
    try {
      const fileSize = file.size;
      const totalChunks = Math.ceil(fileSize / ChunkedUploader.CHUNK_SIZE);
      const uploadSessionId = this.generateSessionId();

      console.log('===== UPLOAD DETAILS =====');
      console.log(`Starting chunked upload: ${file.name}`);
      console.log(`File size: ${(fileSize / 1024 / 1024).toFixed(2)} MB`);
      console.log(`Total chunks: ${totalChunks}`);
      console.log(`Chunk size: ${(ChunkedUploader.CHUNK_SIZE / 1024 / 1024).toFixed(2)} MB`);
      console.log(`Course ID: ${courseId}`);
      console.log(`Lecture ID: ${lectureId || 'Will generate new ID'}`);
      console.log(`Title: ${title}`);
      console.log(`Description: ${description || ''}`);
      console.log(`File Type: ${fileType}`);
      console.log(`Upload Session ID: ${uploadSessionId}`);
      console.log('===== END UPLOAD DETAILS =====');

      // Upload chunks sequentially
      for (let i = 0; i < totalChunks; i++) {
        const start = i * ChunkedUploader.CHUNK_SIZE;
        const end = Math.min(start + ChunkedUploader.CHUNK_SIZE, fileSize);
        
        console.log(`[CHUNK ${i+1}/${totalChunks}] Preparing chunk, size: ${((end - start) / 1024 / 1024).toFixed(2)} MB, range: ${start}-${end} bytes`);
        
        try {
          // Read the chunk from the file
          const chunk = await this.readChunkFromFile(file, start, end);
          console.log(`[CHUNK ${i+1}/${totalChunks}] Successfully read ${chunk.size} bytes from file`);
          
          // Create FormData for the chunk
          const formData = new FormData();
          formData.append('chunk', chunk, file.name);
          formData.append('chunkIndex', i.toString());
          formData.append('totalChunks', totalChunks.toString());
          formData.append('fileName', file.name);
          formData.append('courseId', courseId);
          formData.append('lectureId', lectureId || `lecture_${Date.now()}`);
          formData.append('title', title);
          formData.append('description', description || '');
          formData.append('fileType', fileType);
          formData.append('uploadSessionId', uploadSessionId);
          
          console.log(`[CHUNK ${i+1}/${totalChunks}] Sending to server...`);
          
          try {
            // Send the chunk to the server
            const response = await apiService.uploadChunk(formData);
            console.log(`[CHUNK ${i+1}/${totalChunks}] Response received: ${JSON.stringify(response).substring(0, 100)}...`);
            
            if (response.success) {
              console.log(`[CHUNK ${i+1}/${totalChunks}] Upload successful, updating progress`);
              
              const progress: UploadProgress = {
                chunkIndex: response.chunkIndex ?? i,
                totalChunks: response.totalChunks ?? totalChunks,
                percentage: response.progress?.percentage ?? Math.floor((i + 1) * 100 / totalChunks),
                completed: response.progress?.completed ?? 0,
                total: response.progress?.total ?? 0,
                isComplete: response.isComplete ?? false,
                uploadSessionId: response.uploadSessionId ?? uploadSessionId,
              };
              
              this.onProgress(progress);
              
              if (response.isComplete) {
                console.log('[UPLOAD COMPLETE] Upload finished successfully!');
                console.log(`[UPLOAD COMPLETE] Response: ${JSON.stringify(response).substring(0, 300)}...`);
                
                const result: UploadResult = {
                  fileInfo: response.fileInfo ?? {},
                  progress: response.progress ?? {},
                  uploadSessionId: response.uploadSessionId ?? uploadSessionId,
                };
                
                this.onComplete(result);
                return;
              }
            } else {
              console.log(`[CHUNK ERROR] Upload failed: ${response.error || 'Unknown error'}`);
              console.log(`[CHUNK ERROR] Full response: ${JSON.stringify(response)}`);
              throw new Error(response.error || 'Chunk upload failed');
            }
          } catch (apiError: any) {
            console.log(`[CHUNK API ERROR] Upload request failed: ${apiError}`);
            throw new Error(`Failed to upload chunk to server: ${apiError.message || apiError}`);
          }
        } catch (readError: any) {
          console.log(`[CHUNK ERROR] Failed to read chunk: ${readError}`);
          throw new Error(`Failed to read chunk from file: ${readError.message || readError}`);
        }
      }
    } catch (e: any) {
      console.log('[UPLOAD ERROR] ===== CHUNKED UPLOAD FAILED =====');
      console.log(`[UPLOAD ERROR] Error: ${e}`);
      console.log('[UPLOAD ERROR] Stack trace:', e.stack);
      this.onError(`Upload failed: ${e.message || e}`);
    }
  }

  private async readChunkFromFile(file: File, start: number, end: number): Promise<Blob> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const result = e.target?.result;
        if (result instanceof ArrayBuffer) {
          resolve(new Blob([result], { type: file.type }));
        } else {
          reject(new Error('Failed to read file chunk'));
        }
      };
      reader.onerror = (e) => {
        reject(e);
      };
      reader.readAsArrayBuffer(file.slice(start, end));
    });
  }
}

export default ChunkedUploader;
