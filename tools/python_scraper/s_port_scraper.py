from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import time
import json
import os
from datetime import datetime

# Clean old .json files
events_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), "../../assets/events"))
os.makedirs(events_dir, exist_ok=True)

for file in os.listdir(events_dir):
    if file.endswith(".json"):
        os.remove(os.path.join(events_dir, file))

#Define output files
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
filename = f"up_events_{timestamp}.json"
output_path = os.path.normpath(os.path.join(os.path.dirname(__file__), "../../assets/events", filename))
static_path = os.path.normpath(os.path.join(os.path.dirname(__file__), "../../assets/events/upcoming_events.json"))
os.makedirs(os.path.dirname(output_path), exist_ok=True)

# Setup headless browser
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
options.add_argument("--headless=new")
options.add_argument("--lang=en")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

# Load activities list
driver.get("https://www.aanbod.s-port.nl")  # Load root first to set cookie

# Inject language cookie
driver.add_cookie({
    'name': 'locale',
    'value': 'en',
    'path': '/',
    'domain': 'www.aanbod.s-port.nl'
})

# Now load the actual activities page
driver.get("https://www.aanbod.s-port.nl/activiteiten?gemeente%5B0%5D=40&sort=name&order=asc")

# Page loaded, scrolling...



for i in range(10):
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    time.sleep(2)

WebDriverWait(driver, 15).until(
    EC.presence_of_all_elements_located((By.CSS_SELECTOR, ".activity"))
)

cards = driver.find_elements(By.CSS_SELECTOR, ".activity")
# Found event cards

events = []

def extract_info_dict(raw_text):
    """
    Parse multiline block from .info into structured fields.
    """
    lines = [line.strip() for line in raw_text.split("\n") if line.strip()]
    info = {
        "location": "-",
        "target_group": "-",
        "cost": "-",
        "date_time": "-"
    }
    current_key = None

    for line in lines:
        lower = line.lower()
        if lower.startswith("locatie") or lower.startswith("location"):
            current_key = "location"
        elif lower.startswith("doelgroep") or lower.startswith("target group") or lower.startswith("targetgroup"):
            current_key = "target_group"
        elif lower.startswith("kosten") or lower.startswith("cost"):
            current_key = "cost"
        elif lower.startswith("datum") or lower.startswith("date"):
            current_key = "date_time"
        elif current_key:
            if info[current_key] == "-":
                info[current_key] = line
            else:
                info[current_key] += " | " + line

    # ✅ Clean up trailing junk from date_time (like 'Add to favorites | More info | Sign up')
    if info["date_time"] != "-":
        info["date_time"] = info["date_time"].split("|")[0].strip()

    return info

# Loop through cards
for idx, card in enumerate(cards[:20]):
    try:
        title_elem = card.find_element(By.CSS_SELECTOR, "h2 a")
        title = title_elem.text.strip()
        url = title_elem.get_attribute("href")
    except:
        title = "-"
        url = "-"

    try:
        image_elem = card.find_element(By.CSS_SELECTOR,"img")
        image_url = image_elem.get_attribute("src")
    except:
        image_url = ""

    try:
        organizer = card.find_element(By.CSS_SELECTOR, "span.location").text.strip()
    except:
        organizer = "-"

    try:
        raw_info = card.find_element(By.CSS_SELECTOR, ".info").text.strip()
        info = extract_info_dict(raw_info)
        info["cost"] = info["cost"].lstrip("· ").strip()
    except:
        info = {
            "location": "-",
            "target_group": "-",
            "cost": "-",
            "date_time": "-"
        }

    # Processing event

    events.append({
        "title": title,
        "url": url,
        "organizer": organizer,
        "location": info["location"],
        "target_group": info["target_group"],
        "cost": info["cost"],
        "date_time": info["date_time"],
        "imageUrl" : image_url
    })

# Save JSON
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

# Save also to static name for Flutter to read
with open(static_path, "w", encoding="utf-8") as f:
    json.dump(events, f, ensure_ascii=False, indent=2)


# Clean and structured data saved
driver.quit()
