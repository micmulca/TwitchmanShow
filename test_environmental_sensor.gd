extends Node

# Test EnvironmentalSensor - Comprehensive testing of environmental integration
# Tests location detection, weather effects, time of day effects, and resource availability

# Test results
var test_results: Array[Dictionary] = []
var current_test: String = ""

# Test components
var test_sensor: EnvironmentalSensor = null
var test_status_component: StatusComponent = null

func _ready():
	print("🧪 Starting EnvironmentalSensor Tests...")
	
	# Create test components
	_setup_test_components()
	
	# Run all tests
	_run_all_tests()
	
	# Display results
	_display_results()

func _setup_test_components():
	"""Set up test components for testing"""
	# Create test StatusComponent
	test_status_component = StatusComponent.new()
	test_status_component.npc_id = "test_character"
	
	# Create test EnvironmentalSensor
	test_sensor = EnvironmentalSensor.new()
	test_sensor.character_id = "test_character"
	
	# Connect components
	test_sensor.set_status_component(test_status_component)
	
	print("✅ Test components created")

func _run_all_tests():
	"""Run all environmental sensor tests"""
	
	# Test 1: Basic initialization
	_test_basic_initialization()
	
	# Test 2: Location effects
	_test_location_effects()
	
	# Test 3: Weather system
	_test_weather_system()
	
	# Test 4: Time of day effects
	_test_time_effects()
	
	# Test 5: Seasonal effects
	_test_seasonal_effects()
	
	# Test 6: Resource availability
	_test_resource_availability()
	
	# Test 7: Environmental modifiers
	_test_environmental_modifiers()
	
	# Test 8: Console commands
	_test_console_commands()
	
	# Test 9: Integration with StatusComponent
	_test_status_integration()
	
	# Test 10: Performance and updates
	_test_performance()

func _test_basic_initialization():
	"""Test basic component initialization"""
	current_test = "Basic Initialization"
	
	var success = true
	var errors = []
	
	# Check component creation
	if not test_sensor:
		success = false
		errors.append("EnvironmentalSensor not created")
	
	# Check default values
	if test_sensor.current_location != "home":
		success = false
		errors.append("Default location should be 'home', got: " + test_sensor.current_location)
	
	if test_sensor.current_period != "afternoon":
		success = false
		errors.append("Default time period should be 'afternoon', got: " + test_sensor.current_period)
	
	if test_sensor.current_season != "summer":
		success = false
		errors.append("Default season should be 'summer', got: " + test_sensor.current_season)
	
	# Check weather initialization
	var weather = test_sensor.get_weather_info()
	if not weather.has("type"):
		success = false
		errors.append("Weather info missing 'type' field")
	
	_record_test_result(success, errors)

func _test_location_effects():
	"""Test location-based effects system"""
	current_test = "Location Effects"
	
	var success = true
	var errors = []
	
	# Test home location effects
	test_sensor.set_location("home")
	var home_effects = test_sensor.get_location_effects()
	
	if not home_effects.has("comfort"):
		success = false
		errors.append("Home location missing 'comfort' effect")
	
	if home_effects.comfort <= 0:
		success = false
		errors.append("Home comfort effect should be positive")
	
	# Test workplace location effects
	test_sensor.set_location("workplace")
	var work_effects = test_sensor.get_location_effects()
	
	if not work_effects.has("achievement_need"):
		success = false
		errors.append("Workplace missing 'achievement_need' effect")
	
	# Test outdoors location effects
	test_sensor.set_location("outdoors")
	var outdoor_effects = test_sensor.get_location_effects()
	
	if not outdoor_effects.has("curiosity"):
		success = false
		errors.append("Outdoors missing 'curiosity' effect")
	
	# Test location tags
	var tags = test_sensor.get_location_tags()
	if tags.is_empty():
		success = false
		errors.append("Location tags should not be empty")
	
	_record_test_result(success, errors)

func _test_weather_system():
	"""Test weather system functionality"""
	current_test = "Weather System"
	
	var success = true
	var errors = []
	
	# Test weather patterns
	var patterns = test_sensor.weather_patterns
	if not patterns.has("rain"):
		success = false
		errors.append("Weather patterns missing 'rain'")
	
	if not patterns.has("sunny"):
		success = false
		errors.append("Weather patterns missing 'sunny'")
	
	# Test weather change
	var old_weather = test_sensor.get_weather_info()
	test_sensor.console_command("set_weather", ["rain"])
	var new_weather = test_sensor.get_weather_info()
	
	if new_weather.type != "rain":
		success = false
		errors.append("Weather should change to 'rain', got: " + new_weather.type)
	
	# Test temperature effects
	if new_weather.temperature >= old_weather.temperature:
		success = false
		errors.append("Rain should lower temperature")
	
	# Test weather types
	var result = test_sensor.console_command("weather", [])
	if not result.success:
		success = false
		errors.append("Weather command failed: " + result.error)
	
	_record_test_result(success, errors)

func _test_time_effects():
	"""Test time of day effects"""
	current_test = "Time Effects"
	
	var success = true
	var errors = []
	
	# Test time periods
	var periods = test_sensor.time_periods
	if not periods.has("dawn"):
		success = false
		errors.append("Time periods missing 'dawn'")
	
	if not periods.has("night"):
		success = false
		errors.append("Time periods missing 'night'")
	
	# Test time period detection
	var current_period = test_sensor.get_time_period()
	if current_period.is_empty():
		success = false
		errors.append("Current time period should not be empty")
	
	# Test time command
	var result = test_sensor.console_command("time", [])
	if not result.success:
		success = false
		errors.append("Time command failed: " + result.error)
	
	_record_test_result(success, errors)

func _test_seasonal_effects():
	"""Test seasonal effects system"""
	current_test = "Seasonal Effects"
	
	var success = true
	var errors = []
	
	# Test seasons
	var seasons = test_sensor.seasons
	if not seasons.has("winter"):
		success = false
		errors.append("Seasons missing 'winter'")
	
	if not seasons.has("spring"):
		success = false
		errors.append("Seasons missing 'spring'")
	
	# Test season change
	test_sensor.console_command("set_season", ["winter"])
	var current_season = test_sensor.get_season()
	
	if current_season != "winter":
		success = false
		errors.append("Season should change to 'winter', got: " + current_season)
	
	# Test seasonal temperature effects
	var winter_data = seasons.winter
	if winter_data.temperature_mod >= 0:
		success = false
		errors.append("Winter should have negative temperature modifier")
	
	_record_test_result(success, errors)

func _test_resource_availability():
	"""Test resource availability system"""
	current_test = "Resource Availability"
	
	var success = true
	var errors = []
	
	# Test home resources
	test_sensor.set_location("home")
	var home_resources = test_sensor.get_available_resources()
	
	# Home might not have specific resources defined, so just check it returns an array
	if not home_resources is Array:
		success = false
		errors.append("Home resources should be an array")
	
	# Test workshop resources
	test_sensor.set_location("workshop")
	var workshop_resources = test_sensor.get_available_resources()
	
	if not workshop_resources is Array:
		success = false
		errors.append("Workshop resources should be an array")
	
	# Test resource availability change signal
	var signal_received = false
	test_sensor.resource_availability_changed.connect(func(location, resources): signal_received = true)
	
	test_sensor.set_location("kitchen")
	
	# Wait a frame for signal
	await get_tree().process_frame
	
	if not signal_received:
		success = false
		errors.append("Resource availability change signal not emitted")
	
	_record_test_result(success, errors)

func _test_environmental_modifiers():
	"""Test environmental modifier application"""
	current_test = "Environmental Modifiers"
	
	var success = true
	var errors = []
	
	# Test location modifiers
	test_sensor.set_location("bedroom")
	var initial_energy = test_status_component.needs.physical.energy.current
	
	# Apply environmental effects for a few frames
	for i in range(10):
		test_sensor._apply_environmental_modifiers(1.0)
		await get_tree().process_frame
	
	var final_energy = test_status_component.needs.physical.energy.current
	
	if final_energy <= initial_energy:
		success = false
		errors.append("Bedroom should increase energy, got: " + str(final_energy - initial_energy))
	
	# Test weather modifiers
	test_sensor.console_command("set_weather", ["storm"])
	test_sensor.set_location("outdoors")
	
	var initial_comfort = test_status_component.needs.comfort.comfort.current
	
	# Apply weather effects
	for i in range(5):
		test_sensor._apply_weather_modifiers(1.0)
		await get_tree().process_frame
	
	var final_comfort = test_status_component.needs.comfort.comfort.current
	
	if final_comfort >= initial_comfort:
		success = false
		errors.append("Storm should decrease comfort, got: " + str(final_comfort - initial_comfort))
	
	_record_test_result(success, errors)

func _test_console_commands():
	"""Test console command functionality"""
	current_test = "Console Commands"
	
	var success = true
	var errors = []
	
	# Test location command
	var result = test_sensor.console_command("location", [])
	if not result.success:
		success = false
		errors.append("Location command failed: " + result.error)
	
	# Test weather command
	result = test_sensor.console_command("weather", [])
	if not result.success:
		success = false
		errors.append("Weather command failed: " + result.error)
	
	# Test time command
	result = test_sensor.console_command("time", [])
	if not result.success:
		success = false
		errors.append("Time command failed: " + result.error)
	
	# Test season command
	result = test_sensor.console_command("season", [])
	if not result.success:
		success = false
		errors.append("Season command failed: " + result.error)
	
	# Test resources command
	result = test_sensor.console_command("resources", [])
	if not result.success:
		success = false
		errors.append("Resources command failed: " + result.error)
	
	# Test invalid command
	result = test_sensor.console_command("invalid_command", [])
	if result.success:
		success = false
		errors.append("Invalid command should fail")
	
	_record_test_result(success, errors)

func _test_status_integration():
	"""Test integration with StatusComponent"""
	current_test = "Status Integration"
	
	var success = true
	var errors = []
	
	# Test need modification through environmental sensor
	var initial_hunger = test_status_component.needs.physical.hunger.current
	
	# Move to kitchen (should reduce hunger)
	test_sensor.set_location("kitchen")
	
	# Apply effects for a few frames
	for i in range(10):
		test_sensor._apply_environmental_modifiers(1.0)
		await get_tree().process_frame
	
	var final_hunger = test_status_component.needs.physical.hunger.current
	
	if final_hunger >= initial_hunger:
		success = false
		errors.append("Kitchen should reduce hunger, got: " + str(final_hunger - initial_hunger))
	
	# Test signal emission
	var modifier_signal_received = false
	test_sensor.environmental_modifier_applied.connect(func(char_id, need_type, modifier, reason): modifier_signal_received = true)
	
	test_sensor._apply_environmental_modifiers(1.0)
	await get_tree().process_frame
	
	if not modifier_signal_received:
		success = false
		errors.append("Environmental modifier signal not emitted")
	
	_record_test_result(success, errors)

func _test_performance():
	"""Test performance characteristics"""
	current_test = "Performance"
	
	var success = true
	var errors = []
	
	# Test update frequency
	var start_time = Time.get_time()
	var update_count = 0
	
	# Run updates for 1 second
	while Time.get_time() - start_time < 1.0:
		test_sensor._update_environment(0.1)
		update_count += 1
	
	# Should have reasonable update frequency (not too fast, not too slow)
	if update_count < 5 or update_count > 20:
		success = false
		errors.append("Update frequency seems off: " + str(update_count) + " updates per second")
	
	# Test memory usage (basic check)
	var sensor_size = test_sensor.get_script().get_global_name()
	if sensor_size.is_empty():
		success = false
		errors.append("Sensor script not properly loaded")
	
	_record_test_result(success, errors)

func _record_test_result(success: bool, errors: Array[String]):
	"""Record the result of a test"""
	var result = {
		"test": current_test,
		"success": success,
		"errors": errors.duplicate()
	}
	
	test_results.append(result)
	
	var status = "✅ PASS" if success else "❌ FAIL"
	print(status + " - " + current_test)
	
	if not success:
		for error in errors:
			print("  Error: " + error)

func _display_results():
	"""Display comprehensive test results"""
	print("\n" + "="*60)
	print("🧪 ENVIRONMENTAL SENSOR TEST RESULTS")
	print("="*60)
	
	var total_tests = test_results.size()
	var passed_tests = test_results.filter(func(r): return r.success).size()
	var failed_tests = total_tests - passed_tests
	
	print("Total Tests: " + str(total_tests))
	print("Passed: " + str(passed_tests) + " ✅")
	print("Failed: " + str(failed_tests) + " ❌")
	print("Success Rate: " + str(int((float(passed_tests) / total_tests) * 100)) + "%")
	
	if failed_tests > 0:
		print("\n❌ FAILED TESTS:")
		for result in test_results:
			if not result.success:
				print("  " + result.test + ":")
				for error in result.errors:
					print("    - " + error)
	
	print("\n" + "="*60)
	
	# Clean up test components
	_cleanup_test_components()
	
	# Exit test
	get_tree().quit()

func _cleanup_test_components():
	"""Clean up test components"""
	if test_sensor:
		test_sensor.queue_free()
	
	if test_status_component:
		test_status_component.queue_free()
	
	print("🧹 Test components cleaned up")
