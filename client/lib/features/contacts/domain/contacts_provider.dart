import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/shared/models/contact.dart';

class ContactsRepository {
  final Dio _dio;

  ContactsRepository(this._dio);

  Future<List<Contact>> getContacts({String query = ''}) async {
    final response = await _dio.get('/api/v1/contacts',
        queryParameters: query.isNotEmpty ? {'q': query} : null);
    final data = response.data as List;
    return data.map((json) => Contact.fromJson(json)).toList();
  }

  Future<Contact> getContact(String id) async {
    final response = await _dio.get('/api/v1/contacts/$id');
    return Contact.fromJson(response.data);
  }

  Future<Contact> createContact({
    required String displayName,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final response = await _dio.post('/api/v1/contacts', data: {
      'display_name': displayName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
    });
    return Contact.fromJson(response.data);
  }

  Future<Contact> updateContact(
    String id, {
    String? displayName,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final response = await _dio.put('/api/v1/contacts/$id', data: {
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
    });
    return Contact.fromJson(response.data);
  }

  Future<void> deleteContact(String id) async {
    await _dio.delete('/api/v1/contacts/$id');
  }

  Future<Uint8List> exportContacts({String format = 'vcard'}) async {
    final response = await _dio.get('/api/v1/contacts/export',
        queryParameters: {'format': format},
        options: Options(responseType: ResponseType.bytes));
    return response.data as Uint8List;
  }

  Future<int> importContacts(Uint8List data, {String format = 'vcard'}) async {
    final response = await _dio.post('/api/v1/contacts/import',
        data: data,
        queryParameters: {'format': format},
        options: Options(
          contentType: 'application/octet-stream',
        ));
    return response.data['imported'] ?? 0;
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.read(apiClientProvider).dio);
});

class ContactsState {
  final List<Contact> contacts;
  final bool isLoading;
  final String? error;

  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
  });

  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? error,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  final ContactsRepository _repository;
  String _currentQuery = '';

  ContactsNotifier(this._repository) : super(const ContactsState());

  Future<void> loadContacts({String query = ''}) async {
    _currentQuery = query;
    state = state.copyWith(isLoading: true);
    try {
      final contacts = await _repository.getContacts(query: query);
      state = state.copyWith(contacts: contacts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load contacts');
    }
  }

  Future<void> refreshContacts() async {
    await loadContacts(query: _currentQuery);
  }

  Future<Contact?> createContact({
    required String displayName,
    String? email,
    String? phone,
    String? notes,
  }) async {
    try {
      final contact = await _repository.createContact(
        displayName: displayName,
        email: email,
        phone: phone,
        notes: notes,
      );
      state = state.copyWith(contacts: [...state.contacts, contact]);
      return contact;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create contact');
      return null;
    }
  }

  Future<Contact?> updateContact(
    String id, {
    String? displayName,
    String? email,
    String? phone,
    String? notes,
  }) async {
    try {
      final contact = await _repository.updateContact(id,
          displayName: displayName, email: email, phone: phone, notes: notes);
      state = state.copyWith(
        contacts: state.contacts.map((c) => c.id == id ? contact : c).toList(),
      );
      return contact;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update contact');
      return null;
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await _repository.deleteContact(id);
      state = state.copyWith(
        contacts: state.contacts.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete contact');
    }
  }

  Future<int> importContacts(Uint8List data, {String format = 'vcard'}) async {
    try {
      final count = await _repository.importContacts(data, format: format);
      await refreshContacts();
      return count;
    } catch (e) {
      state = state.copyWith(error: 'Failed to import contacts');
      return 0;
    }
  }

  Future<Uint8List?> exportContacts({String format = 'vcard'}) async {
    try {
      return await _repository.exportContacts(format: format);
    } catch (e) {
      state = state.copyWith(error: 'Failed to export contacts');
      return null;
    }
  }
}

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  return ContactsNotifier(ref.read(contactsRepositoryProvider));
});
