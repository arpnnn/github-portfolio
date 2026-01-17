import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.model_selection import StratifiedShuffleSplit, cross_validate
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.naive_bayes import GaussianNB
import xgboost as xgb
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    precision_score,
    recall_score,
    accuracy_score,
    f1_score)

#EDA
# Load data from .csv
credit_data = pd.read_csv("creditcard_2023.csv")
credit_data.info()
credit_data.head()
credit_data.tail()

#2. Train/Test Split
split = StratifiedShuffleSplit(n_splits=1, test_size=0.2, random_state=42)

for train_index, test_index in split.split(credit_data, credit_data["Class"]):
    train_set = credit_data.loc[train_index]
    test_set = credit_data.loc[test_index]

#Separate features and labels from training and testing data
x_train = train_set.drop(["Class", "id"], axis=1)
y_train = train_set["Class"]
x_test = test_set.drop(["Class", "id"], axis=1)
y_test = test_set["Class"]

#3. Creating model pipeline
scale_pos_weight = (y_train==0).sum() / (y_train==1).sum()

log_reg_pipeline = Pipeline([
    ("scaler", StandardScaler()),
    ("model", LogisticRegression(max_iter=1000, random_state=42, class_weight='balanced'))
])

tree_pipeline = Pipeline([
    ("scaler", StandardScaler()),
    ("model", DecisionTreeClassifier(random_state=42, class_weight='balanced'))
])

forest_pipeline = Pipeline([
    ("model", RandomForestClassifier(
        n_estimators=100,
        max_depth=10,        # limit tree depth
        min_samples_split=5,
        random_state=42
    ))
])

xgb_pipeline = Pipeline([
    ("scaler", StandardScaler()),
    ("model", xgb.XGBClassifier(n_estimators=100, random_state=42, scale_pos_weight=scale_pos_weight))
])

#4. Train each model and evaluate

    #1.Logistic Regression
log_reg_pipeline.fit(x_train, y_train)
y_pred_log = log_reg_pipeline.predict(x_test)
print(f"Precision: {precision_score(y_test, y_pred_log)}")
print(f"Recall:  {recall_score(y_test, y_pred_log)}")
print(f"F1:      {f1_score(y_test, y_pred_log)}")
print(f"Confusion Matrix:\n{confusion_matrix(y_test, y_pred_log)}")

    #Logistic Regression Confusion Matrix
cm = confusion_matrix(y_test, y_pred_log)
plt.figure(figsize=(6, 4))
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", cbar=False)
plt.xlabel("Predicted Label")
plt.ylabel("True Label")
plt.title("Logistic Regression Confusion Matrix")
plt.show()

    #2. #Decision Tree
tree_pipeline.fit(x_train, y_train)
y_pred_tree = tree_pipeline.predict(x_test)
print(f"Precision: {precision_score(y_test, y_pred_tree)}")
print(f"Recall:  {recall_score(y_test, y_pred_tree)}")
print(f"F1:      {f1_score(y_test, y_pred_tree)}")
print(f"Confusion Matrix:\n{confusion_matrix(y_test, y_pred_tree)}")

    #Decision Tree Confusion Matrix
cm = confusion_matrix(y_test, y_pred_tree)
plt.figure(figsize=(6, 4))
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", cbar=False)
plt.xlabel("Predicted Label")
plt.ylabel("True Label")
plt.title("Decision Tree Confusion Matrix")
plt.show()

    #3.Random Forest
y_pred_forest = forest_pipeline.predict(x_test)
print("After training")
print(f"Precision: {precision_score(y_test, y_pred_forest)}")
print(f"Recall:  {recall_score(y_test, y_pred_forest)}")
print(f"F1:      {f1_score(y_test, y_pred_forest)}")
print(f"Confusion Matrix:\n{confusion_matrix(y_test, y_pred_forest)}")

    #Random Forest Confusion Matrix
cm = confusion_matrix(y_test, y_pred_forest)
plt.figure(figsize=(6, 4))
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", cbar=False)
plt.xlabel("Predicted Label")
plt.ylabel("True Label")
plt.title("Random Forest Confusion Matrix")
plt.show()

    #4. XGBoost
xgb_pipeline.fit(x_train, y_train)
y_pred_xgb = xgb_pipeline.predict(x_test)
print(f"Precision: {precision_score(y_test, y_pred_xgb)}")
print(f"Recall:  {recall_score(y_test, y_pred_xgb)}")
print(f"F1:      {f1_score(y_test, y_pred_xgb)}")
print(f"Confusion Matrix:\n{confusion_matrix(y_test, y_pred_xgb)}")

    #XGBoost Confusion Matrix
cm = confusion_matrix(y_test, y_pred_xgb)
plt.figure(figsize=(6, 4))
sns.heatmap(cm, annot=True, fmt="d", cmap="YlGnBu", cbar=False)
plt.xlabel("Predicted Label")
plt.ylabel("True Label")
plt.title("XGBoost Confusion Matrix")
plt.show()




