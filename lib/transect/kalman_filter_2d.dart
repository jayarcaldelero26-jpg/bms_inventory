import 'dart:math';

class KalmanFilter2D {
  // State: [x, y, vx, vy]
  List<double> x = [0, 0, 0, 0];

  // Covariance matrix
  List<List<double>> P =
      List.generate(4, (_) => List.filled(4, 0));

  final double processNoise;
  final double measurementNoise;

  KalmanFilter2D({
    this.processNoise = 0.5,
    this.measurementNoise = 8,
  }) {
    for (int i = 0; i < 4; i++) {
      P[i][i] = 1;
    }
  }

  void reset(double px, double py) {
    x = [px, py, 0, 0];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        P[i][j] = i == j ? 1 : 0;
      }
    }
  }

  void predict(double dt) {
    // position prediction
    x[0] += x[2] * dt;
    x[1] += x[3] * dt;

    // increase uncertainty
    for (int i = 0; i < 4; i++) {
      P[i][i] += processNoise;
    }
  }

  void update(double mx, double my, double accuracy) {
    final r = max(measurementNoise, accuracy);

    final kx = P[0][0] / (P[0][0] + r);
    final ky = P[1][1] / (P[1][1] + r);

    x[0] += kx * (mx - x[0]);
    x[1] += ky * (my - x[1]);

    P[0][0] *= (1 - kx);
    P[1][1] *= (1 - ky);
  }
}
