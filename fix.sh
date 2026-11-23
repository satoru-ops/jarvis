#!/bin/bash
set -e

# Olmayan round icon satırını kaldır
sed -i '/android:roundIcon/d' app/src/main/AndroidManifest.xml

# Bozuk PNG'leri sil
rm -f app/src/main/res/mipmap-*/ic_launcher_foreground.png

# Vektör simge oluştur
mkdir -p app/src/main/res/drawable
cat > app/src/main/res/drawable/ic_launcher_foreground.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#2AB7FF"
        android:pathData="M54,54m-24,0a24,24 0 1,1 48,0a24,24 0 1,1 -48,0" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M54,54m-9,0a9,9 0 1,1 18,0a9,9 0 1,1 -18,0" />
</vector>
EOF

# Adaptive icon artık vektörü kullansın
cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_bg" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
EOF

git add -A
git commit -m "Simge duzeltildi"
git push