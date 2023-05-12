<?php

namespace MacsiDigital\API\Support\Authentication;

use Firebase\JWT\Key;
use Firebase\JWT\JWT as FirebaseJWT;

class JWT
{
    public static function generateToken($token, $secret, $alg = 'HS256')
    {
        return FirebaseJWT::encode($token, $secret, $alg);
    }

    public static function decodeToken($jwt, $secret, $alg = 'HS256')
    {
        return FirebaseJWT::decode($jwt, new Key($secret, $alg));
    }
}
