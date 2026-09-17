import os
import sys
import json
import pandas as pd
import pytest

os.environ["DATA_BUCKET"] = "test-bucket"

current_dir = os.path.dirname(os.path.abspath(__file__))
lambda_folder = os.path.join(current_dir,"../lambdas/transform")

sys.path.insert(0,lambda_folder)

from handler import to_dataframe

@pytest.fixture
def earthquakes_data():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    fixture_path = os.path.join(current_dir,"sample_earthquakes.json")
    with open(fixture_path,"rb") as f:
        return f.read()


def test_row_count(earthquakes_data):
    df = to_dataframe(earthquakes_data)
    assert len(df) == 2


def test_drops_missing_magnitude(earthquakes_data):
    df = to_dataframe(earthquakes_data)
    assert "eq2" not in df["id"].values


def test_dedupes_by_id(earthquakes_data):
    df = to_dataframe(earthquakes_data)
    assert list(df["id"]).count("eq3") == 1


def test_keeps_first_duplicate(earthquakes_data):
    df = to_dataframe(earthquakes_data)
    eq3_row = df[df["id"] == "eq3"].iloc[0]
    assert eq3_row["magnitude"] == 3.2


def test_event_time_is_datetime(earthquakes_data):
    df = to_dataframe(earthquakes_data)
    assert pd.api.types.is_datetime64_any_dtype(df["event_time"])
