// Copyright (c) 2018 Sergey Yelin
//
// This file is provided to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file
// except in compliance with the License.  You may obtain
// a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

#pragma once
#ifndef INCL_RATELIMITER_H
#define INCL_RATELIMITER_H

#include <mutex>
#include <memory>

#include "erl_nif.h"

// Forward declaration
namespace rocksdb {
    class RateLimiter;
}

namespace erocksdb {

  class RateLimiter {
    protected:
      static ErlNifResourceType* m_RateLimiter_RESOURCE;

    public:
      std::mutex mu;

      explicit RateLimiter(std::shared_ptr<rocksdb::RateLimiter> rate_limiter);

      ~RateLimiter();

      std::shared_ptr<rocksdb::RateLimiter> rate_limiter();

      static void CreateRateLimiterType(ErlNifEnv * Env);
      static void RateLimiterResourceCleanup(ErlNifEnv *Env, void * Arg);

      static RateLimiter * CreateRateLimiterResource(std::shared_ptr<rocksdb::RateLimiter> rate_limiter);
      static RateLimiter * RetrieveRateLimiterResource(ErlNifEnv * Env, const ERL_NIF_TERM & RateLimiterTerm);

    private:
      std::shared_ptr<rocksdb::RateLimiter> rate_limiter_;
  };

}

#endif // INCL_RATELIMITER_H