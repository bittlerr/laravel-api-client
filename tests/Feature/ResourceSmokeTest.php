<?php

namespace MacsiDigital\API\Tests\Feature;

use MacsiDigital\API\Contracts\Relation;
use MacsiDigital\API\Dev\User;
use PHPUnit\Framework\TestCase;

class ResourceSmokeTest extends TestCase
{
    public function test_resource_sets_and_gets_attributes(): void
    {
        $user = new User(null, ['name' => 'Alice', 'email' => 'alice@example.com']);

        $this->assertSame('Alice', $user->name);
        $this->assertSame('alice@example.com', $user->email);
    }

    public function test_resource_to_array_includes_attributes(): void
    {
        $user = new User(null, ['name' => 'Bob']);

        $this->assertArrayHasKey('name', $user->toArray());
        $this->assertSame('Bob', $user->toArray()['name']);
    }

    public function test_resource_json_encode_roundtrip(): void
    {
        $user = new User(null, ['name' => 'Carol']);
        $decoded = json_decode((string) $user, true);

        $this->assertIsArray($decoded);
        $this->assertSame('Carol', $decoded['name']);
    }

    public function test_resource_attribute_mutation_via_magic_set(): void
    {
        $user = new User(null, []);
        $user->name = 'Dana';

        $this->assertSame('Dana', $user->name);
    }

    public function test_address_relationship_method_returns_relation(): void
    {
        $user = new User(null, []);

        $this->assertInstanceOf(Relation::class, $user->address());
    }

    // Regression: setAttribute() routes truthy values through isDateAttribute(),
    // which calls in_array($key, $this->getDates()). If $dates is not defaulted
    // to an array, PHP 8+ throws TypeError.
    public function test_setting_truthy_non_date_attribute_does_not_explode(): void
    {
        $user = new User(null, []);
        $user->age = 42;

        $this->assertSame(42, $user->age);
    }
}
