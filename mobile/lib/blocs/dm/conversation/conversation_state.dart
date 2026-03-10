// ABOUTME: State for ConversationBloc.

part of 'conversation_bloc.dart';

enum ConversationStatus { initial, loading, loaded, error }

enum SendStatus { idle, sending, sent, failed }

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ConversationStatus.initial,
    this.messages = const [],
    this.sendStatus = SendStatus.idle,
    this.sendError,
  });

  final ConversationStatus status;
  final List<DmMessage> messages;
  final SendStatus sendStatus;
  final String? sendError;

  ConversationState copyWith({
    ConversationStatus? status,
    List<DmMessage>? messages,
    SendStatus? sendStatus,
    String? sendError,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sendStatus: sendStatus ?? this.sendStatus,
      sendError: sendError ?? this.sendError,
    );
  }

  @override
  List<Object?> get props => [status, messages, sendStatus, sendError];
}
