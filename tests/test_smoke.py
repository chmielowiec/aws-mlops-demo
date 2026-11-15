"""Smoke test: local package always; live endpoint when ENDPOINT_NAME is set."""
import json, os, subprocess, sys, tarfile

import pytest

SAMPLE = [[5.1, 3.5, 1.4, 0.2]]  # setosa -> class 0


def test_package_predicts(tmp_path):
    out = tmp_path / "model.tar.gz"
    subprocess.run([sys.executable, "train.py", "--out", str(out)], check=True)
    tarfile.open(out).extractall(tmp_path / "m")
    sys.path.insert(0, str(tmp_path / "m" / "code"))
    from inference import model_fn
    assert model_fn(str(tmp_path / "m")).predict(SAMPLE).tolist() == [0]


@pytest.mark.skipif(not os.getenv("ENDPOINT_NAME"), reason="no live endpoint")
def test_endpoint_predicts():
    import boto3
    r = boto3.client("sagemaker-runtime").invoke_endpoint(
        EndpointName=os.environ["ENDPOINT_NAME"], ContentType="application/json", Body=json.dumps(SAMPLE))
    assert json.loads(r["Body"].read()) == [0]
