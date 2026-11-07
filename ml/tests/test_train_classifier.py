import pandas as pd

from training.train_classifier import train


def test_train_fits_a_pipeline_that_predicts_a_known_label():
    labels = pd.DataFrame(
        {
            "title": [
                "Dell R630 Server 2x E5-2650v4 64GB RAM",
                "HP DL380 Gen9 Server 128GB RAM",
                "Supermicro 2U Server Dual Xeon",
                "Lenovo Workstation Tower Xeon",
                "Intel Xeon E5-2650 v4 CPU Only",
                "32GB DDR4 RDIMM Server Memory Stick",
                "HDD Caddy for Dell R630 3.5 inch",
                "Replacement Fan for HP DL380 Server",
            ],
            "label": ["computer", "computer", "computer", "computer", "part", "part", "part", "part"],
        }
    )

    pipeline = train(labels)

    prediction = pipeline.predict(["Dell PowerEdge R630 Server"])

    assert prediction[0] in {"computer", "part"}
