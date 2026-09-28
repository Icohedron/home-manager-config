"""Re-authorise Copilot even when LiteLLM has cached a revoked OAuth token."""

import os
from pathlib import Path
from tempfile import TemporaryDirectory

from litellm.llms.github_copilot.authenticator import Authenticator


def main():
    token_dir = Path(os.environ["GITHUB_COPILOT_TOKEN_DIR"])

    # get_api_key() trusts any cached access-token without checking it. Use an
    # empty directory to force the device flow; leave existing credentials
    # untouched if the browser login or Copilot token exchange fails.
    with TemporaryDirectory(prefix="atuin-ai-login-") as fresh:
        os.environ["GITHUB_COPILOT_TOKEN_DIR"] = fresh
        try:
            Authenticator().get_api_key()
        finally:
            os.environ["GITHUB_COPILOT_TOKEN_DIR"] = str(token_dir)

        credentials = {
            name: (Path(fresh) / name).read_bytes()
            for name in ("access-token", "api-key.json")
        }
        if not all(credentials.values()):
            raise RuntimeError("Copilot login did not return both credentials")

        token_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        token_dir.chmod(0o700)
        # Stage both files before replacing either. Never leave world-readable
        # tokens on disk, even if the user's umask is permissive.
        with TemporaryDirectory(prefix=".atuin-ai-login-", dir=token_dir) as stage:
            for name, data in credentials.items():
                path = Path(stage) / name
                path.write_bytes(data)
                path.chmod(0o600)
            for name in credentials:
                os.replace(Path(stage) / name, token_dir / name)

    print("Atuin AI: GitHub Copilot authenticated.")


if __name__ == "__main__":
    main()
