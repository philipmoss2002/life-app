@echo off
echo Setting up Android App Signing...
echo.
echo You need to enter the passwords you used when creating the keystore.
echo.

set /p STORE_PASSWORD="Enter your keystore password: "
set /p KEY_PASSWORD="Enter your key password (or press Enter if same as keystore): "

if "%KEY_PASSWORD%"=="" set KEY_PASSWORD=%STORE_PASSWORD%

echo.
echo Updating key.properties file...

(
echo storePassword=%STORE_PASSWORD%
echo keyPassword=%KEY_PASSWORD%
echo keyAlias=upload
echo storeFile=../upload-keystore.jks
) > android\key.properties

echo.
echo ✅ Signing configuration updated!
echo.
echo You can now build a signed AAB with:
echo flutter build appbundle --release
echo.
pause