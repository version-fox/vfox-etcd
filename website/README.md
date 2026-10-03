# Documentation site

Chinese: https://version-fox.github.io/vfox-etcd/
English: https://version-fox.github.io/vfox-etcd/en/

Build with Python's standard library:

```sh
python3 website/build.py --output /tmp/vfox-etcd-site
python3 -m http.server 8080 --directory /tmp/vfox-etcd-site
```

Open http://localhost:8080/ or /en/. A shared template and matching Chinese/English message files render both routes. site.json holds shared commands and canonical configuration. The builder reads plugin version and minimum vfox runtime from metadata.lua and rejects missing or unused template messages. Use --base-url for another deployment URL.

Pages builds PRs, deploys main, and refreshes from trusted main after successful publication, including tag releases. Official logos are stored without modification; see assets/LOGO-SOURCE.txt. Reading the guides, switching languages and opening FAQ entries work without JavaScript. JavaScript adds accessible command tabs and copying.
