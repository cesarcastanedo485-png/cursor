# Push this project to GitHub (for My Repos in Mordechaius Maximus)

Your local repo is ready: **1 commit on `main`**, no remote yet. GitHub CLI is not installed, so use the steps below.

---

## 1. Create the repo on GitHub

**Suggested repo name:** `mordechaius-maximus` or `cursor-mobile` (use one that doesn’t already exist under your account).

**Option A — Browser**

1. Open **https://github.com/new**
2. **Repository name:** `mordechaius-maximus` (or your choice)
3. **Description:** optional, e.g. `Mordechaius Maximus — Flutter app (Cloud Agents, Private AIs, Capabilities)`
4. Choose **Private**
5. **Do not** add a README, .gitignore, or license (you already have them locally)
6. Click **Create repository**

**Option B — If you install GitHub CLI later**

```powershell
gh repo create mordechaius-maximus --private --source=. --remote=origin --push
```

---

## 2. Add remote and push (replace `YOUR_USERNAME` with your GitHub username)

```powershell
cd C:\Users\cmc\mordechaius-maximus

git remote add origin https://github.com/YOUR_USERNAME/mordechaius-maximus.git
git push -u origin main
```

Example: if your username is `jane`, use  
`https://github.com/jane/mordechaius-maximus.git`

---

## 3. If Git asks for credentials (HTTPS)

- **Username:** your GitHub username  
- **Password:** use a **Personal Access Token (PAT)**, not your GitHub password.

**Create a PAT:**

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. **Generate new token (classic)** → name it (e.g. `cursor_mobile_push`) → enable scope **`repo`**
3. Generate and **copy the token**
4. When `git push` asks for password, **paste the token**

**Optional (save credentials so you don’t re-enter):**

```powershell
git config --global credential.helper store
```

After the next successful push, Git will reuse the stored credentials.

---

## 4. After a successful push

- **Repo URL:** `https://github.com/YOUR_USERNAME/mordechaius-maximus` (or whatever you named it).
- In the **Mordechaius Maximus** app: open **My Repos**, pull to refresh. The repo should appear once **GitHub is connected in Cursor** (Cursor dashboard / desktop) and Cursor has synced your GitHub repos.

---

## 5. Set your Git identity (optional but recommended)

The initial commit used a placeholder. For future commits with your name/email:

```powershell
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

To fix the author on the last commit only:

```powershell
git commit --amend --reset-author --no-edit
git push --force-with-lease origin main
```
