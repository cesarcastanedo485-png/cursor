# Put this project on GitHub (one-time)

**You don’t have to** host the app on GitHub for it to run on your phone (the APK works on its own).  
You **do** want GitHub if you want:

- Backups and version history  
- **Cursor / My Repos** (when the API works) to see this project  
- To open the same code on another PC or in Cursor Cloud Agents  

---

## Status on this machine

- Git is initialized on branch **`main`**.  
- **`origin`** is set to:  
  `https://github.com/cesarcastanedo485-png/mordechaius-maximus.git`  
- The remote repo **does not exist yet** — create it, then push once.

---

## Steps (about 2 minutes)

1. Open **https://github.com/new** while logged in as **cesarcastanedo485-png**.

2. Set:
   - **Repository name:** `mordechaius-maximus`  
   - **Private** (recommended)  
   - **Do not** add README, .gitignore, or license (this repo already has them).

3. Click **Create repository**.

4. In PowerShell:

```powershell
cd C:\Users\cmc\cursor_mobile
git push -u origin main
```

If Git asks for credentials, use a **GitHub Personal Access Token** (with `repo` scope) as the password, not your GitHub account password.

---

## After a successful push

Your app code will live at:

**https://github.com/cesarcastanedo485-png/mordechaius-maximus**

Future updates:

```powershell
cd C:\Users\cmc\cursor_mobile
git add -A
git commit -m "Describe your change"
git push
```
