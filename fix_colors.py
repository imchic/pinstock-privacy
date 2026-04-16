import re, os

FILES = [
  "lib/features/settings/views/settings_screen.dart",
  "lib/features/finance/views/finance_screen.dart",
  "lib/features/home/views/home_screen.dart",
  "lib/features/alerts/views/alerts_screen.dart",
  "lib/features/feed/views/feed_screen.dart",
  "lib/features/feed/views/news_web_view_screen.dart",
  "lib/features/feed/views/breaking_news_ticker.dart",
  "lib/features/feed/views/news_detail_screen.dart",
  "lib/features/trends/views/trends_screen.dart",
]

replacements = [
  (r'AppColors\.bg\b',            'context.colors.bg'),
  (r'AppColors\.surface\b',       'context.colors.surface'),
  (r'AppColors\.surfaceLight\b',  'context.colors.surfaceLight'),
  (r'AppColors\.border\b',        'context.colors.border'),
  (r'AppColors\.textPrimary\b',   'context.colors.textPrimary'),
  (r'AppColors\.textSecondary\b', 'context.colors.textSecondary'),
]

base = "/Users/admin/Desktop/dev/flutter/stock_hub"
for f in FILES:
  path = os.path.join(base, f)
  if not os.path.exists(path):
    print(f"SKIP (not found): {f}")
    continue
  with open(path, 'r') as fh:
    content = fh.read()
  orig = content
  for pattern, repl in replacements:
    content = re.sub(pattern, repl, content)
  if content != orig:
    with open(path, 'w') as fh:
      fh.write(content)
    print(f"updated: {f}")
  else:
    print(f"no change: {f}")
