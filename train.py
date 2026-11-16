"""Train iris model, register it in MLflow as iris@champion, package champion for SageMaker."""
import argparse, shutil, tarfile, tempfile
from pathlib import Path

import joblib, mlflow
from mlflow import MlflowClient
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression

NAME = "iris"
CODE = Path(__file__).parent / "serving"


def main(out: str, broken: bool) -> None:
    mlflow.set_tracking_uri("sqlite:///mlflow.db")
    X, y = load_iris(return_X_y=True)
    with mlflow.start_run():
        model = LogisticRegression(max_iter=500).fit(X, y)
        mlflow.log_metric("train_accuracy", model.score(X, y))
        mlflow.sklearn.log_model(model, artifact_path="model", registered_model_name=NAME)
    client = MlflowClient()
    v = client.search_model_versions(f"name='{NAME}'", order_by=["version_number DESC"], max_results=1)[0].version
    client.set_registered_model_alias(NAME, "champion", v)

    champion = mlflow.sklearn.load_model(f"models:/{NAME}@champion")
    with tempfile.TemporaryDirectory() as d:
        joblib.dump(champion, f"{d}/model.joblib")
        if broken:  # corrupt artifact: fails whichever model_fn the container ends up using
            Path(f"{d}/model.joblib").write_bytes(b"broken release")
        shutil.copytree(CODE, f"{d}/code")
        with tarfile.open(out, "w:gz") as t:
            for p in Path(d).iterdir():
                t.add(p, arcname=p.name)
    print(f"registered {NAME} v{v} as champion -> {out}")


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("--out", default="model.tar.gz")
    a.add_argument("--broken", action="store_true")
    args = a.parse_args()
    main(args.out, args.broken)
