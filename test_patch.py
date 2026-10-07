from patchright.sync_api import sync_playwright

with sync_playwright() as p:
    # Launch the patched browser
    browser = p.chromium.launch(headless=False)
    page = browser.new_page()
    # Navigate to a target site
    page.goto('https://www.peakbagger.com/peak.aspx?pid=74023')
    print("Page Title:", page)
    browser.close()
