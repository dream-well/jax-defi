// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./JaxToken.sol";

contract JAXUD is JaxToken {

  constructor() JaxToken("Jax Dollar", "JAX DOLLAR", 18){}  
  
}
