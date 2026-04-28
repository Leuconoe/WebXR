# Wolvic WebXR Static Crawl

This project contains a static crawl of `https://www.wolvic.com/en/start/`.

## Files

- `index.html`: crawled Wolvic start page HTML, with the original gallery markup and scripts preserved.
- `assets/img`, `assets/js`, `assets/font`, `assets/remote`: local copies of page assets.
- `scripts/crawl-wolvic-static.ps1`: re-crawls the Wolvic start page and rewrites asset URLs to local files.

## Re-Crawl

```powershell
.\scripts\crawl-wolvic-static.ps1
```

## Validation Mode

For validation, the crawled page currently removes Wolvic's `3DoF-friendly` toggle and `Featured` section. Random ordering on refresh is also disabled, so samples stay in the same order while you check them.

When validation is complete, random ordering can be restored in `index.html` by re-enabling the two shuffle areas in `startup()`:

- Featured selection: the block that shuffled `#scase` and picked three items.
- Tab ordering: the block that ran `shuffle(collection)` and `tab.prepend(...collection)`.

The same transforms are controlled in `scripts/crawl-wolvic-static.ps1`, so update that script too if you want the behavior to survive future re-crawls.

## Excluding Samples

Each sample in `index.html` has a comment like:

```html
<!-- SAMPLE: Moon Rider | classes: item dof6 | 제외하려면 바로 아래 <a class="item..."> 전체 블록을 HTML 주석으로 감싸세요. -->
<a class="item dof6 " href="https://moonrider.xyz/">
  ...
</a>
```

To hide a sample, wrap the whole `<a class="item...">...</a>` block immediately below the `SAMPLE:` comment in an HTML comment. Do not wrap the category `<h3>` or the parent `<div class="explore grid ...">`, only the single item anchor.

## Run Locally

Use a local HTTP server so the module script loads reliably:

```powershell
python -m http.server 8080
```

Then open `http://localhost:8080`.
