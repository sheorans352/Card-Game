@echo off
echo ==========================================
echo   STAGING: RESTARTING n8n WITH ALL PERMISSIONS
echo ==========================================

echo [1/3] Stopping current n8n container...
docker stop n8n

echo [2/3] Removing current n8n...
docker rm n8n

echo [3/3] Creating new n8n with BUILTIN modules enabled...
docker run -d --name n8n ^
  -p 5678:5678 ^
  -v n8n_data:/home/node/.n8n ^
  -v D:/:/d_drive ^
  -e GENERIC_TIMEZONE=Asia/Kolkata ^
  -e TZ=Asia/Kolkata ^
  -e N8N_RUNNERS_ENABLED=true ^
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false ^
  -e N8N_BLOCK_FS_WRITE_ACCESS=false ^
  -e NODEJS_BUILTIN_MODULES="fs,path" ^
  -e NODEJS_EXTERNAL_MODULES="fs,path" ^
  -e NODES_EXCLUDE="[]" ^
  --restart always ^
  docker.n8n.io/n8nio/n8n

echo.
echo ==========================================
echo   SUCCESS: n8n is restarting at:
echo   http://localhost:5678
echo   (Full Code Node Power Enabled)
echo ==========================================
pause
