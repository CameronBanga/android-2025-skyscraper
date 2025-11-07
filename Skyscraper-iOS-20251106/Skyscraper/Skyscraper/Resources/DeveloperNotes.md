# Developer Notes

## About This App

My name is [Cameron](https://bsky.app/profile/cameronbanga.com), and I'm working on Skyscraper as a way to create the app I wanted for Bluesky. It's a bit of a passion side-project, so apologies if the pace of updates doesn't meet expectations.

We now have 100 test users! A big thank you for everyone who has signed up. Feel free to submit feedback in TestFlight (a couple of you already have!), or email me at [hi@cameron.software](mailto:hi@cameron.software).

I have the current version as 0.7, and consider this very alpha. We are still a way out, so please be patient. I will be adding users in small batches to TestFlight.

---

## Latest Updates

### 2025-11-06
- Any color can now be your accent color.
- First go at adding Moderation features.
- You can preview feeds in Discover mode now.
- Save or share images that you view.
- Emoji now render right on the compose view.
- Added a "Liked" tab when viewing your own profile.
- A number of minor visual fixes.
- Scrolling *may* be smoother. 

### 2025-11-03
- I think I may finally have some profile view fixes. I think I got the post view down, and you can now see media in people's profile pages. 

### 2025-10-29
- You may have issues with post history, please send me notes and see the comment two posts below!
- Special shoutout to Gerry, [@hermitary.myatproto.social](https://bsky.app/profile/hermitary.myatproto.social) for his great TestFlight feedback. His first feedback encouraged me to add alternate PDS support, and his other feedbacks were great and very detailed. I know I can't fix everything for everyone, but these are very helpful. Additional thanks to the 4-5 of you who also submitted posts. Most of the posts are anonymous, so I don't know who you are. There are SO MANY edge cases, so the feedback screenshots are VERY VERY helpful to get an idea of the issues.
- I think I bonked a lot of the feed loading in that last build. I'm hoping this is better. The problem is, most of the issues come during "cold starts", and I see them after I try the app after closing for a few hours. So I push a build and then sad face. I apologize for the mess, but this is an alpha.
- Fixed Browse Feeds page.
- A handful of dark mode fixes.
- Working on alternate PDS support. Chat isn't supported on those yet?

### 2025-10-27
- OK, maybe firehose wasn't the right way, but it gave some good insight. Going back to the general post API. Continuing to work to improve feed load.
- We have added Alt-PDS support, abd it's very early. Are you on an alt PDS? GIVE ME FEEDBACK.
- In general, posts should be loading in better. It's better for me! How about for you?

### 2025-10-26
- I've reworked the entire "fetch new posts" function to use the Bluesky Firehose API instead. I'm not sure that this is an intended use for the API, but it doesn't use much network data and is faster and seems to offer a better potential future than fetching and adding new posts to the feed. I've undoubtably added many new bugs and issues, please report. If you think this is worse, let me know too.
- Added "Mark as Read" functionality to Activity tab
- Fixed duplicate posts in pinned feeds
- Added correct support for scrollToTop in Timeline views
- Added this Developer Notes feature.
- Added Draft posts when composing. Save ideas for later!
- Dark mode fixes

---

## Known Issues

- Profile formatting, particularly of posts and replies, is bad. I have some Swift UI work to fix. Having a hard time getting these to look good.

### 2025-10-26


