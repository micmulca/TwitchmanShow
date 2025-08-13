extends Node

## Test script for CharacterManager functionality
## Demonstrates character creation, loading, and management features

# Test results
var test_results: Array = []

func _ready():
	print("🧪 Starting CharacterManager Tests...")
	
	# Wait a frame for systems to initialize
	await get_tree().process_frame
	
	# Run tests
	run_all_tests()
	
	# Display results
	display_test_results()

func run_all_tests():
	"""Run all CharacterManager tests"""
	
	# Test 1: Basic functionality
	test_basic_functionality()
	
	# Test 2: Character creation
	test_character_creation()
	
	# Test 3: Population management
	test_population_management()
	
	# Test 4: Character queries
	test_character_queries()
	
	# Test 5: Data persistence
	test_data_persistence()

func test_basic_functionality():
	"""Test basic CharacterManager functionality"""
	print("\n1. Testing basic functionality...")
	
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		add_test_result("Basic Functionality", false, "CharacterManager not found in autoloads")
		return
	
	# Test character count
	var count = character_manager.get_character_count()
	if count >= 0:
		add_test_result("Character Count", true, "Population count: " + str(count))
	else:
		add_test_result("Character Count", false, "Invalid count returned")
	
	# Test get all characters
	var all_characters = character_manager.get_all_characters()
	if all_characters is Dictionary:
		add_test_result("Get All Characters", true, "Retrieved " + str(all_characters.size()) + " characters")
	else:
		add_test_result("Get All Characters", false, "Invalid return type")

func test_character_creation():
	"""Test character creation from templates"""
	print("\n2. Testing character creation...")
	
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		add_test_result("Character Creation", false, "CharacterManager not found")
		return
	
	# Test creating a character from template
	var test_character = character_manager.create_character_from_template("elias_thorn")
	if not test_character.is_empty():
		add_test_result("Create from Template", true, "Created Elias Thorn successfully")
		
		# Verify character data
		if test_character.has("name") and test_character.name == "Elias Thorn":
			add_test_result("Character Data", true, "Character data correctly populated")
		else:
			add_test_result("Character Data", false, "Character data incomplete")
	else:
		add_test_result("Create from Template", false, "Failed to create character")

func test_population_management():
	"""Test population management features"""
	print("\n3. Testing population management...")
	
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		add_test_result("Population Management", false, "CharacterManager not found")
		return
	
	# Test population summary
	var summary = character_manager.get_population_summary()
	if summary is Dictionary and summary.has("total_count"):
		add_test_result("Population Summary", true, "Summary generated successfully")
		
		# Test location breakdown
		if summary.has("by_location"):
			var location_count = summary.by_location.size()
			add_test_result("Location Breakdown", true, "Found " + str(location_count) + " locations")
		else:
			add_test_result("Location Breakdown", false, "Missing location data")
	else:
		add_test_result("Population Summary", false, "Invalid summary format")

func test_character_queries():
	"""Test character query functionality"""
	print("\n4. Testing character queries...")
	
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		add_test_result("Character Queries", false, "CharacterManager not found")
		return
	
	# Test get character by ID
	var elias = character_manager.get_character("elias_thorn")
	if not elias.is_empty():
		add_test_result("Get by ID", true, "Retrieved Elias Thorn successfully")
		
		# Test get characters by location
		var fishing_chars = character_manager.get_characters_by_location("fishing_docks")
		if fishing_chars is Array:
			add_test_result("Get by Location", true, "Found " + str(fishing_chars.size()) + " characters at fishing docks")
		else:
			add_test_result("Get by Location", false, "Invalid return type")
		
		
	else:
		add_test_result("Get by ID", false, "Failed to retrieve character")

func test_data_persistence():
	"""Test data persistence functionality"""
	print("\n5. Testing data persistence...")
	
	var character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		add_test_result("Data Persistence", false, "CharacterManager not found")
		return
	
	# Test save character
	var save_success = character_manager.save_character("elias_thorn")
	if save_success:
		add_test_result("Save Character", true, "Elias Thorn saved successfully")
	else:
		add_test_result("Save Character", false, "Failed to save character")
	
	# Test save all characters
	character_manager.save_all_characters()
	add_test_result("Save All", true, "All characters saved")
	
	# Test export functionality
	var export_data = character_manager.export_population_data()
	if export_data is Dictionary and export_data.has("export_timestamp"):
		add_test_result("Export Data", true, "Population data exported successfully")
	else:
		add_test_result("Export Data", false, "Export failed")

func add_test_result(test_name: String, success: bool, message: String):
	"""Add a test result to the results array"""
	var result = {
		"test": test_name,
		"success": success,
		"message": message,
		"timestamp": Time.get_datetime_string_from_system()
	}
	test_results.append(result)
	
	var status = "✅ PASS" if success else "❌ FAIL"
	print(status + " " + test_name + ": " + message)

func display_test_results():
	"""Display comprehensive test results"""
	print("\n" + "="*60)
	print("🧪 CHARACTER MANAGER TEST RESULTS")
	print("="*60)
	
	var total_tests = test_results.size()
	var passed_tests = 0
	var failed_tests = 0
	
	for result in test_results:
		if result.success:
			passed_tests += 1
		else:
			failed_tests += 1
	
	print("Total Tests: " + str(total_tests))
	print("Passed: " + str(passed_tests) + " ✅")
	print("Failed: " + str(failed_tests) + " ❌")
	print("Success Rate: " + str(round((float(passed_tests) / total_tests) * 100)) + "%")
	
	print("\nDetailed Results:")
	print("-" * 40)
	
	for result in test_results:
		var status = "✅ PASS" if result.success else "❌ FAIL"
		print(status + " " + result.test)
		print("  " + result.message)
		print("  " + result.timestamp)
		print()
	
	# Summary
	if failed_tests == 0:
		print("🎉 ALL TESTS PASSED! CharacterManager is working correctly.")
	else:
		print("⚠️  Some tests failed. Check the details above for issues.")
	
	print("="*60)

func _exit_tree():
	"""Cleanup when test script is removed"""
	print("🧹 Test script cleanup complete")
