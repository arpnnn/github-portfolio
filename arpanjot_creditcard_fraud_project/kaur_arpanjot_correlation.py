import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

#Load data from .csv
df = pd.read_csv("creditcard_2023.csv")

# Drop 'id' column for correlation analysis
credit_data_corr = df.drop('id', axis=1)

# Calculate correlation matrix
correlation_matrix = credit_data_corr.corr()

# Display correlation with target variable 'Class'
class_correlation = correlation_matrix['Class'].sort_values(ascending=False)

#Heatmap of top 15 most correlated features
top_n = 15
top_features = class_correlation.head(top_n).index.tolist()
plt.figure(figsize=(10, 8))
sns.heatmap(credit_data_corr[top_features].corr(), annot=True, fmt='.2f', 
            cmap='Spectral', center=0, square=True, linewidths=1)
plt.title('Features Correlation Heatmap')
plt.savefig('correlation_matrix_full.png', dpi=300, bbox_inches='tight')
plt.tight_layout()
plt.show()