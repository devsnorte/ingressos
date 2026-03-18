# Ingressos

Ticketing platform for Devs Norte community events in Northern Brazil. Based on [pretix](https://pretix.eu/) (AGPL v3).

## Setup

```bash
git clone --recurse-submodules https://github.com/devsnorte/ingressos.git
cd ingressos/pretix
git remote add upstream https://github.com/pretix/pretix.git
```

## Syncing with upstream pretix

```bash
cd pretix
git fetch upstream
git merge upstream/master
git push origin master
cd ..
git add pretix
git commit -m "chore: sync pretix with upstream"
git push
```

## Deploying

```bash
fly deploy --app ingressos
```

## License

Based on pretix, licensed under AGPL v3. See [pretix/LICENSE](pretix/LICENSE).
