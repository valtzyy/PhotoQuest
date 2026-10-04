package com.photoquest.app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth membutuhkan FragmentActivity untuk menampilkan dialog biometrik,
// sehingga MainActivity harus extends FlutterFragmentActivity (bukan FlutterActivity).
class MainActivity : FlutterFragmentActivity()
