# Login Background Images

## How to add your images

1. **Open the asset catalog**
   - In Xcode, open **Assets.xcassets** (in the Project Navigator under RSBBQOperations).

2. **Use the existing image sets (or add more)**
   - You’ll see **LoginBG1** and **LoginBG2**. Each is an “Image Set” that can hold your background image.
   - **To add an image:** select **LoginBG1**, then drag your image file from the Finder into the **1x** (or **2x/3x**) slot in the inspector. You can drag the same image into all three slots; Xcode will use it for all scales.
   - Repeat for **LoginBG2** with a different image.

3. **Adding more than two backgrounds**
   - In the asset catalog, click the **+** at the bottom of the left sidebar and choose **Image Set**.
   - Name it using the pattern **LoginBG3**, **LoginBG4**, etc.
   - Drag your image(s) into the set.
   - In **LoginView.swift**, add the new name to the `loginBackgroundImageNames` array (e.g. `"LoginBG3"`, `"LoginBG4"`).

4. **Image tips**
   - Use landscape or square images that look good when scaled to fill the screen (e.g. 1200×800 or larger).
   - The app uses **scaledToFill** and clips overflow, so the image will fill the screen and the login box will sit on top.
