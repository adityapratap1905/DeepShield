import 'package:equatable/equatable.dart';

/// Base failure class for the error handling layer.
/// All feature-specific errors extend this.
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Network-related failures (no internet, timeout, DNS)
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection. Please check your network.', super.statusCode});
}

/// Server returned an error response (4xx / 5xx)
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

/// Authentication failure (401 / 403)
class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Authentication failed. Please log in again.', super.statusCode});
}

/// Request timed out
class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message = 'Request timed out. Please try again.', super.statusCode});
}

/// Invalid input from the user
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

/// Local storage / cache failure
class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Local data error. Please try again.'});
}

/// Unknown / unexpected failure
class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Something went wrong. Please try again.'});
}
