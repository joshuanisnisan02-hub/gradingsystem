# Upload SmartGrade using GitHub Desktop

1. Download and extract `SmartGrade_Flutter_Supabase_Repository.zip`.
2. Install and open GitHub Desktop: https://desktop.github.com/
3. Sign in to the GitHub account `joshuanisnisan02-hub`.
4. Select **File > Add local repository**.
5. Browse to the extracted `gradingsystem` folder and select it.
6. Confirm that the current branch is **main**.
7. Click **Push origin**.
8. Open https://github.com/joshuanisnisan02-hub/gradingsystem and refresh it.

The ZIP includes the existing Git history and correct GitHub remote. Do not choose **Create a new repository** because the `gradingsystem` repository already exists.

## Run in VS Code

1. Open the extracted folder in VS Code.
2. Open a terminal and run:

   ```bash
   flutter create --platforms=web,windows,android .
   flutter pub get
   ```

3. Open **Run and Debug**.
4. Select **SmartGrade Web** or **SmartGrade Windows**.
5. Press **F5**.
