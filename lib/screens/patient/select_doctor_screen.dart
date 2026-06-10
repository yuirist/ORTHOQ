import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';
import '../../widgets/doctor_avatar.dart';
import 'patient_information_screen.dart';

class SelectDoctorScreen extends StatefulWidget {
  final String appointmentType; // 'new_patient' or 'follow_up'

  const SelectDoctorScreen({
    super.key,
    required this.appointmentType,
  });

  @override
  State<SelectDoctorScreen> createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  final DoctorService _doctorService = DoctorService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Set<String> _favoriteDoctorIds = <String>{};

  final List<String> _categories = ['All', 'Spine', 'Sports', 'Legs'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select a Specialist',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search name or speciality...',
                  prefixIcon: Icon(Icons.search, color: Colors.black87),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),

          // Category Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      selectedColor: OrthoqColors.slateNavy,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Doctor List
          Expanded(
            child: StreamBuilder<List<DoctorModel>>(
              stream: _selectedCategory == 'All'
                  ? _doctorService.getActiveDoctors()
                  : _doctorService.getDoctorsBySpecialization(_selectedCategory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allDoctors = snapshot.data ?? [];
                
                // Filter by search query
                final filteredDoctors = allDoctors.where((doctor) {
                  if (_searchQuery.isEmpty) return true;
                  final nameMatch = doctor.name.toLowerCase().contains(_searchQuery);
                  final specializationMatch = doctor.specialization.toLowerCase().contains(_searchQuery);
                  return nameMatch || specializationMatch;
                }).toList();

                if (filteredDoctors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No doctors found matching "$_searchQuery"'
                              : 'No doctors available',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = filteredDoctors[index];
                    return _DoctorCard(
                      doctor: doctor,
                      isFavorite: _favoriteDoctorIds.contains(doctor.id),
                      onToggleFavorite: () {
                        setState(() {
                          if (_favoriteDoctorIds.contains(doctor.id)) {
                            _favoriteDoctorIds.remove(doctor.id);
                          } else {
                            _favoriteDoctorIds.add(doctor.id);
                          }
                        });
                      },
                      onSelect: () {
                        // Navigate to patient information screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientInformationScreen(
                              doctorId: doctor.id,
                              appointmentType: widget.appointmentType,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSelect;

  const _DoctorCard({
    required this.doctor,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onSelect,
  });

  // Get availability days (mock data - in real app, this would come from doctor's schedule)
  String _getAvailabilityDays() {
    // This is placeholder - in a real app, you'd fetch this from the doctor's schedule
    // For now, we'll use a simple mapping based on specialization
    if (doctor.specialization.toLowerCase().contains('spine')) {
      return 'Mon, Wed, Fri';
    } else if (doctor.specialization.toLowerCase().contains('sports')) {
      return 'Tue, Thu, Sat';
    } else {
      return 'Mon, Wed, Fri';
    }
  }

  // Get availability time (mock data)
  String _getAvailabilityTime() {
    return '10:00 AM - 04:00 PM';
  }

  // Get specialty tag (extract from specialization or use category)
  String _getSpecialtyTag() {
    final spec = doctor.specialization.toLowerCase();
    if (spec.contains('spine')) return 'Spine';
    if (spec.contains('sports')) return 'Sports';
    if (spec.contains('leg') || spec.contains('knee') || spec.contains('foot')) return 'Legs';
    // Extract first word or use specialization
    return doctor.specialization.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Specialty Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: OrthoqColors.slateNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getSpecialtyTag(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Doctor Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.specialization,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Availability
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            _getAvailabilityDays(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            _getAvailabilityTime(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? const Color(0xFFE57373) // Soft red when favorited
                        : const Color(0xFF4A5568), // Slate gray when empty
                  ),
                ),

                DoctorAvatar(
                  imageUrl: doctor.imageUrl,
                  radius: 30,
                  backgroundColor: OrthoqColors.slateNavy,
                  iconColor: Theme.of(context).colorScheme.onPrimary,
                  iconSize: 40,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Select Doctor Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrthoqColors.slateNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Select Doctor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


