import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/driver_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/assigned_vehicle_card.dart';
import '../widgets/primary_button.dart';

/// Écran d'édition du profil du livreur Dokan Delivery.
/// Permet la modification du nom, du téléphone et de la région d'affectation.
/// Affiche la section véhicule de flotte en lecture seule stricte.
class EditProfileScreen extends StatefulWidget {
  final DriverProfile? initialProfile;
  final ProfileService? profileService;
  final AuthService? authService;

  const EditProfileScreen({
    super.key,
    this.initialProfile,
    this.profileService,
    this.authService,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final ProfileService _profileService;
  late final AuthService _authService;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  String? _selectedRegionId;
  DriverProfile? _currentProfile;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _authService = widget.authService ?? AuthService();

    _nameController = TextEditingController();
    _phoneController = TextEditingController();

    if (widget.initialProfile != null) {
      _applyProfile(widget.initialProfile!);
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _applyProfile(DriverProfile profile) {
    _currentProfile = profile;
    _nameController.text = profile.name.isNotEmpty
        ? profile.name
        : (_authService.currentUser?.displayName ?? '');
    _phoneController.text = profile.phone;
    _selectedRegionId = DeliveryRegion.findById(profile.assignedRegionId)?.id ??
        DeliveryRegion.nord.id;
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      _currentProfile = DriverProfile(
        uid: '',
        name: user?.displayName ?? 'Livreur Dokan',
        email: user?.email ?? '',
      );
      _nameController.text = _currentProfile!.name;
      _selectedRegionId = DeliveryRegion.nord.id;
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profile = await _profileService.getProfile(uid: uid);
      if (!mounted) return;
      if (profile != null) {
        _applyProfile(profile);
      } else {
        _applyProfile(
          DriverProfile(
            uid: uid,
            name: user?.displayName ?? '',
            email: user?.email ?? '',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _applyProfile(
          DriverProfile(
            uid: uid,
            name: user?.displayName ?? '',
            email: user?.email ?? '',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    // Retrait du focus clavier
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    final region = DeliveryRegion.findById(_selectedRegionId);
    if (region == null) {
      AppSnackBar.showError(
        context,
        'Veuillez sélectionner une zone d\'affectation officielle.',
      );
      return;
    }

    final targetUid = _currentProfile?.uid.isNotEmpty == true
        ? _currentProfile!.uid
        : (_authService.currentUser?.uid ?? '');

    if (targetUid.isEmpty) {
      AppSnackBar.showError(
        context,
        'Identifiant du livreur introuvable. Veuillez vous reconnecter.',
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await _profileService.updateDriverProfile(
        uid: targetUid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        regionId: region.id,
        regionName: region.name,
      );

      final updatedProfile = (_currentProfile ?? DriverProfile(uid: targetUid)).copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        assignedRegionId: region.id,
        assignedRegionName: region.name,
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      AppSnackBar.showSuccess(context, 'Profil mis à jour avec succès !');

      // Renvoi du profil mis à jour à l'écran appelant
      Navigator.pop(context, updatedProfile);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        'Erreur lors de la sauvegarde du profil : $e',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Bannière d'information
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(
                          alpha: isDark ? 0.15 : 0.65,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mettez à jour vos coordonnées et votre zone d\'activité pour l\'attribution des livraisons.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.primaryDark,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 1. Informations Personnelles Modifiables ───────
                    Text(
                      'Informations personnelles',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Champ Nom Complet
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        hintText: 'Ex: Mohamed Ben Ali',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Le nom complet est obligatoire';
                        }
                        if (trimmed.length < 2) {
                          return 'Le nom doit contenir au moins 2 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Champ Numéro de Téléphone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: 'Ex: 98 123 456 ou +216 98 123 456',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Le numéro de téléphone est obligatoire';
                        }
                        final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly.length < 8) {
                          return 'Numéro invalide (au moins 8 chiffres)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Dropdown Zone d'affectation / Région ─────────────
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRegionId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Zone d\'affectation / Région',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      items: DeliveryRegion.officialRegions.map((region) {
                        return DropdownMenuItem<String>(
                          value: region.id,
                          child: Text(
                            region.fullLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedRegionId = newId);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner une zone d\'affectation';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 26),

                    // ── 2. Section Véhicule de Flotte (LECTURE SEULE) ───
                    AssignedVehicleCard(
                      vehiclePlate: _currentProfile?.assignedVehiclePlate,
                      vehicleModel: _currentProfile?.assignedVehicleModel,
                      vehicleType: _currentProfile?.assignedVehicleType,
                      showHeader: true,
                    ),

                    const SizedBox(height: 30),

                    // ── 3. Bouton d'enregistrement ──────────────────────
                    PrimaryButton(
                      label: 'Enregistrer les modifications',
                      icon: Icons.check_rounded,
                      isLoading: _isSaving,
                      onPressed: _saveChanges,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
