//! Independent project and upstream attribution links.

/// The independent LightStrike source repository.
pub const GITHUB: &str = "https://github.com/Gerbzz/LightStrike";
/// The source project, credited without implying its endorsement.
pub const UPSTREAM: &str = "https://github.com/storytold/lightcraft";

/// (UI command id, menu label, URL) for each link, in Help-menu order.
/// The user documentation (docs/ in the repository).
pub const HELP: &str = "https://github.com/Gerbzz/LightStrike/tree/main/docs";

pub const LINKS: &[(&str, &str, &str)] = &[
    ("app.help", "LightStrike Help", HELP),
    ("app.website", "Original LightCraft source", UPSTREAM),
    ("app.github", "LightStrike on GitHub", GITHUB),
    ("app.feedback", "Send Feedback…", FEEDBACK),
];

/// Where feedback and bug reports go.
pub const FEEDBACK: &str = "https://github.com/Gerbzz/LightStrike/issues/new";

/// The URL behind a link command id.
pub fn url_of(cmd: &str) -> Option<&'static str> {
    LINKS.iter().find(|(id, _, _)| *id == cmd).map(|(_, _, u)| *u)
}

/// Open `url` in the user's browser (through the host's `open_url` service).
pub fn open(app: &mut crate::LightcraftApp, url: &str) -> Result<serde_json::Value, String> {
    let open = app.services.open_url.as_mut().ok_or("can't open links here")?;
    open(url)?;
    Ok(serde_json::json!({ "url": url }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn links_are_https_and_credit_the_source() {
        for (id, label, url) in LINKS {
            assert!(url.starts_with("https://"), "{id}");
            assert!(!label.is_empty());
            assert_eq!(url_of(id), Some(*url));
        }
        assert!(GITHUB.ends_with("/Gerbzz/LightStrike"));
        assert!(UPSTREAM.ends_with("/storytold/lightcraft"));
    }
}
