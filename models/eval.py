from sklearn.metrics import mean_absolute_percentage_error
import numpy as np

class CustomMAPE:
    def __init__(self):
        self.mape_ = mean_absolute_percentage_error

    def forward(self, predict, target):
        # 替换target中的零值
        label_mean = np.mean(target[target != 0])
        target = np.where(target == 0, label_mean, target)
        return self.mape_(target, predict)

# 示例用法
if __name__ == "__main__":
    predict = np.array([10, 20, 30, 40])
    target = np.array([12, 18, 0, 40])
    label_mean = np.mean(target[target != 0])

    custom_mape = CustomMAPE()
    mape_value = custom_mape.forward(predict, target, label_mean=label_mean)
    print(f"Mean Absolute Percentage Error: {mape_value}")