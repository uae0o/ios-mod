@echo off
cd /d "F:\new menu m0hammed\sileo-repo"
echo [1/2] Scanning .deb packages and updating Packages index (Rootless + RootHide + Rootful)...
wsl -e bash -c "sed -i 's/\r$//' '/mnt/f/new menu m0hammed/sileo-repo/update-repo.sh' '/mnt/f/new menu m0hammed/sileo-repo/Release' && bash '/mnt/f/new menu m0hammed/sileo-repo/update-repo.sh'"

echo.
echo [2/2] Uploading new .deb packages and Packages index to GitHub (uae0o/ios-mod)...
git config core.autocrlf false
git pull --rebase origin main
git add -A
git diff --cached --quiet || git commit -m "Update Sileo repo packages"
git push -u origin main

echo.
echo ============================================================
echo Done! Your Sileo Repo is live at:
echo https://uae0o.github.io/ios-mod/
echo ============================================================
pause
