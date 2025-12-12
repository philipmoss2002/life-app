@echo off
echo Creating Android App Signing Keystore...
echo.
echo You will be prompted to enter:
echo 1. Keystore password (remember this!)
echo 2. Key password (can be same as keystore password)
echo 3. Your name and organization details
echo.
pause

"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

echo.
echo Keystore created successfully!
echo File location: upload-keystore.jks
echo.
echo IMPORTANT: Remember your passwords and keep this keystore file safe!
echo You'll need it for all future app updates.
echo.
pause