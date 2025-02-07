import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

def plot(T):
  rotation = T[:3, :3]
  translation = T[3, :3]
  print(translation)
  print(rotation[0, :])

  origin = np.array([translation[0], translation[1], translation[2]])
  x_axis = origin + rotation[0, :]
  y_axis = origin + rotation[1, :]
  z_axis = origin + rotation[2, :] 

  fig = plt.figure(figsize=(8, 8))
  ax = fig.add_subplot(111, projection='3d')

  ax.scatter(*origin, color='black', s=50, label="Transformed Origin")
  ax.scatter(*[0, 0, 0], color="orange", s=50, label="True origin")

  ax.quiver(*origin, *(x_axis-origin), color='r', label="X-Axis", arrow_length_ratio=0.1)
  ax.quiver(*origin, *(y_axis-origin), color='g', label="Y-Axis", arrow_length_ratio=0.1)
  ax.quiver(*origin, *(z_axis-origin), color='b', label="Z-Axis", arrow_length_ratio=0.1)

  ax.set_xlabel("X-axis")
  ax.set_ylabel("Y-axis")
  ax.set_zlabel("Z-axis")
  ax.set_title("3D Spatial Transformation Representation")
  ax.legend()
  ax.set_xlim([-2, 2])
  ax.set_ylim([-2, 2])
  ax.set_zlim([-2, 2])

  plt.show()


T = np.array([[-0.004577864, 0.97680044, -0.21410249, 0.0], 
              [-0.9742513, -0.052620314, -0.21923871, 0.0], 
              [-0.22541863, 0.20758598, 0.95188993, 0.0], 
              [0.11782905, 0.09656975, -0.6512399, 1.0]])
plot(T)

T = np.array([[-0.0045778668, -0.9742512, -0.22541861, 0.0], [0.97680044, -0.05262031, 0.20758598, 0.0], [-0.2141025, -0.21923871, 0.95188993, 0.0], [-0.23322207, -0.022900375, 0.62642306, 1.0]])

plot(T)