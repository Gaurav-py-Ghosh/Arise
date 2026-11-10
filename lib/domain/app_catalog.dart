/// Default tagging of apps. The user can override "distracting" per app;
/// overrides are stored in the database and win over everything here.
library;

const social = 'social';
const video = 'video';
const games = 'games';
const music = 'music';
const browse = 'browser';
const comms = 'comms';
const dev = 'dev';
const reading = 'reading';
const shopping = 'shopping';
const other = 'other';

const _distractingCategories = {social, video, games, shopping};

/// Well-known packages. Anything missing falls back to Android's own
/// app category, then to [other].
const Map<String, String> knownApps = {
  'com.instagram.android': social,
  'com.facebook.katana': social,
  'com.facebook.lite': social,
  'com.twitter.android': social,
  'com.snapchat.android': social,
  'com.reddit.frontpage': social,
  'com.zhiliaoapp.musically': social,
  'com.ss.android.ugc.trill': social,
  'com.pinterest': social,
  'com.linkedin.android': social,
  'com.discord': social,
  'org.telegram.messenger': comms,
  'com.whatsapp': comms,
  'com.whatsapp.w4b': comms,
  'com.google.android.apps.messaging': comms,
  'com.google.android.gm': comms,
  'com.google.android.dialer': comms,
  'com.slack': comms,
  'com.microsoft.teams': comms,
  'com.google.android.youtube': video,
  'com.netflix.mediaclient': video,
  'com.amazon.avod.thirdpartyclient': video,
  'in.startv.hotstar': video,
  'com.jio.media.ondemand': video,
  'tv.twitch.android.app': video,
  'com.crunchyroll.crunchyroid': video,
  'com.google.android.apps.youtube.music': music,
  'com.spotify.music': music,
  'com.jio.media.jiobeats': music,
  'com.apple.android.music': music,
  'com.android.chrome': browse,
  'org.mozilla.firefox': browse,
  'com.brave.browser': browse,
  'com.opera.browser': browse,
  'com.microsoft.emmx': browse,
  'com.github.android': dev,
  'com.termux': dev,
  'com.stackexchange.stackoverflow': dev,
  'com.anthropic.claude': dev,
  'com.openai.chatgpt': dev,
  'com.google.android.apps.bard': dev,
  'md.obsidian': dev,
  'com.amazon.kindle': reading,
  'com.google.android.apps.books': reading,
  'com.amazon.mShop.android.shopping': shopping,
  'com.flipkart.android': shopping,
  'com.myntra.android': shopping,
  'in.swiggy.android': shopping,
  'com.application.zomato': shopping,
};

/// Values of android.content.pm.ApplicationInfo.category.
String _fromSystemCategory(int c) => switch (c) {
      0 => games,
      1 => music, // audio
      2 => video,
      4 => social,
      5 => reading, // news
      7 => other, // productivity
      _ => other,
    };

String categoryOf(String package, int systemCategory) =>
    knownApps[package] ?? _fromSystemCategory(systemCategory);

bool defaultDistracting(String package, int systemCategory) =>
    _distractingCategories.contains(categoryOf(package, systemCategory));

bool isDistracting(
        String package, int systemCategory, Map<String, bool> overrides) =>
    overrides[package] ?? defaultDistracting(package, systemCategory);
