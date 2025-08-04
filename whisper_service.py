#!/usr/bin/env python3

import sys
import os
import json
import whisper
import numpy as np
import soundfile as sf
from flask import Flask, request, jsonify
import threading
import queue
import time

app = Flask(__name__)

class WhisperService:
    def __init__(self, model_name="base"):
        print(f"Loading Whisper model: {model_name}")
        self.model = whisper.load_model(model_name)
        self.processing_queue = queue.Queue()
        self.results = {}
        
        worker_thread = threading.Thread(target=self._process_queue)
        worker_thread.daemon = True
        worker_thread.start()
    
    def _process_queue(self):
        while True:
            try:
                job_id, audio_path = self.processing_queue.get(timeout=1)
                result = self._transcribe(audio_path)
                self.results[job_id] = result
                
                try:
                    os.remove(audio_path)
                except:
                    pass
                    
            except queue.Empty:
                continue
            except Exception as e:
                print(f"Error processing: {e}")
    
    def _transcribe(self, audio_path):
        try:
            result = self.model.transcribe(audio_path)
            return {
                "text": result["text"],
                "language": result.get("language", "en"),
                "segments": result.get("segments", [])
            }
        except Exception as e:
            return {"error": str(e)}
    
    def queue_transcription(self, audio_path):
        job_id = f"job_{int(time.time() * 1000)}"
        self.processing_queue.put((job_id, audio_path))
        return job_id
    
    def get_result(self, job_id):
        return self.results.pop(job_id, None)

whisper_service = WhisperService()

@app.route('/transcribe', methods=['POST'])
def transcribe():
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400
    
    audio_file = request.files['audio']
    temp_path = f"/tmp/whisper_{int(time.time() * 1000)}.wav"
    audio_file.save(temp_path)
    
    job_id = whisper_service.queue_transcription(temp_path)
    
    return jsonify({"job_id": job_id})

@app.route('/result/<job_id>', methods=['GET'])
def get_result(job_id):
    result = whisper_service.get_result(job_id)
    if result is None:
        return jsonify({"status": "processing"}), 202
    
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "model": "base"})

if __name__ == '__main__':
    print("Starting Whisper service on port 5555...")
    app.run(host='127.0.0.1', port=5555, debug=False)