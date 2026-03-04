# Store logo backgrounds (Out of Stock tiles)

Each Out of Stock tile can show that store’s logo as a background. Logos are loaded from the app’s **asset catalog** using a fixed naming rule.

## Where to add the images

1. In Xcode, open **Assets.xcassets** (under **RSBBQOperations** in the Project Navigator).
2. Add one **Image Set** per store logo.
3. **Name** the image set exactly as below. The name is case-sensitive.

## Naming rule

Use: **`StoreLogo_`** + the store code, with spaces replaced by underscores.

| Store code (from API) | Image set name in Assets |
|----------------------|--------------------------|
| `001`                | `StoreLogo_001`          |
| `North Store`        | `StoreLogo_North_Store`  |
| `Store-A`            | `StoreLogo_StoreA` (hyphens/other non-alphanumeric chars are removed) |

- Spaces in the store code become **`_`** in the asset name.
- Only letters, numbers, and underscores are kept; other characters (e.g. `-`, `'`) are removed. So `Store-A` → **`StoreLogo_StoreA`**. Name your image set to match.

To see the exact name the app uses for a store:

- In code, the name is: **`StoreLogo_`** + store code with spaces → `_`, and then only letters, numbers, and `_` kept.  
  Example: `"North Store"` → **`StoreLogo_North_Store`**.  
  So create an image set named **`StoreLogo_North_Store`** and drag your logo into the 1x (and 2x/3x if you want) slot.

## Adding a logo

1. In **Assets.xcassets**, click the **+** at the bottom of the left sidebar.
2. Choose **Image Set**.
3. Name it using the rule above (e.g. **StoreLogo_001**).
4. Select the new image set, then drag your logo image into the **1x** (and optionally **2x** / **3x**) slot in the inspector.

The logo appears behind the tile content at 35% opacity. If no image set exists for a store code, the tile still shows the store name and count with the default material background.
