import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_user.dart';
import 'auth_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {
  const AppStarted();
}

class SignInSubmitted extends AuthEvent {
  const SignInSubmitted({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class DemoSignInRequested extends AuthEvent {
  const DemoSignInRequested();
}

class SignUpSubmitted extends AuthEvent {
  const SignUpSubmitted({
    required this.email,
    required this.password,
    required this.displayName,
    required this.avatarEmoji,
    required this.avatarColorValue,
  });
  final String email;
  final String password;
  final String displayName;
  final String avatarEmoji;
  final int avatarColorValue;
  @override
  List<Object?> get props =>
      [email, password, displayName, avatarEmoji, avatarColorValue];
}

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

class ProfileUpdateRequested extends AuthEvent {
  const ProfileUpdateRequested({
    this.displayName,
    this.avatarEmoji,
    this.avatarColorValue,
  });
  final String? displayName;
  final String? avatarEmoji;
  final int? avatarColorValue;
  @override
  List<Object?> get props => [displayName, avatarEmoji, avatarColorValue];
}

// ─── States ─────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// Restoring a persisted session at boot.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error, this.busy = false});
  final String? error;
  final bool busy;
  @override
  List<Object?> get props => [error, busy];
}

// ─── Bloc ───────────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthLoading()) {
    on<AppStarted>(_onAppStarted);
    on<SignInSubmitted>(_onSignIn);
    on<DemoSignInRequested>(_onDemoSignIn);
    on<SignUpSubmitted>(_onSignUp);
    on<SignOutRequested>(_onSignOut);
    on<ProfileUpdateRequested>(_onProfileUpdate);
  }

  final AuthRepository _repository;

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final user = await _repository.restoreSession();
    emit(user != null ? AuthAuthenticated(user) : const AuthUnauthenticated());
  }

  Future<void> _onSignIn(SignInSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthUnauthenticated(busy: true));
    try {
      final user = await _repository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthUnauthenticated(error: e.message));
    } catch (_) {
      emit(const AuthUnauthenticated(error: 'Sign-in failed. Please try again.'));
    }
  }

  Future<void> _onDemoSignIn(
    DemoSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthUnauthenticated(busy: true));
    try {
      final user = await _repository.signInDemo();
      emit(AuthAuthenticated(user));
    } catch (_) {
      emit(const AuthUnauthenticated(
        error: 'Demo sign-in failed. Please try again.',
      ));
    }
  }

  Future<void> _onSignUp(SignUpSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthUnauthenticated(busy: true));
    try {
      final user = await _repository.signUp(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
        avatarEmoji: event.avatarEmoji,
        avatarColorValue: event.avatarColorValue,
      );
      emit(AuthAuthenticated(user));
    } on AuthFailure catch (e) {
      emit(AuthUnauthenticated(error: e.message));
    } catch (_) {
      emit(const AuthUnauthenticated(error: 'Sign-up failed. Please try again.'));
    }
  }

  Future<void> _onSignOut(SignOutRequested event, Emitter<AuthState> emit) async {
    await _repository.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onProfileUpdate(
    ProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previous = state;
    try {
      final user = await _repository.updateProfile(
        displayName: event.displayName,
        avatarEmoji: event.avatarEmoji,
        avatarColorValue: event.avatarColorValue,
      );
      emit(AuthAuthenticated(user));
    } on AuthFailure {
      // UI validates input before dispatching; keep the current session.
      if (previous is AuthAuthenticated) emit(previous);
    }
  }
}
