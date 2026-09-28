/// The links that leave the app.
///
/// Kept in one place so the URL the settings screen opens and the URL a test
/// asserts are the same string, and so the next link has somewhere to go that
/// is not a widget file.
///
/// Both open in whatever app handles the link — the browser, never an in-app
/// webview — which is also why the app itself still needs no internet
/// permission: the request belongs to the browser, not to Dhimmah.
abstract final class AppLinks {
  const AppLinks._();

  /// The privacy policy, served by GitHub Pages from the repository's `docs/`.
  /// The same URL the Play listing carries.
  static final Uri privacyPolicy = Uri.parse(
    'https://alsrkal.github.io/Dhimmah/privacy/',
  );
}
