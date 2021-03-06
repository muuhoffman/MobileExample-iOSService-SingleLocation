(function() {
  'use strict';

  angular.module('application', [
    'ui.router',
    'ngAnimate',

    //foundation
    'foundation',
    'foundation.dynamicRouting',
    'foundation.dynamicRouting.animations'
  ]).controller('singleLocationController',
    function($scope, $http){
      $scope.location = "Test";
      $http.get('http://pmapi/location/single').then(function(response){
        console.log("singlelocation response: ",response);
        $scope.coordinates = response.data;
        return response.data;
      }).then(function(location) {
        $http.get('http://pmapi/location/address?' 
          + 'latitude=' + location.latitude 
          + '&longitude=' + location.longitude)
        .then(function(response){
          $scope.address = response.data;
        });
      });

  })
    .config(config)
    .run(run)
  ;

  config.$inject = ['$urlRouterProvider', '$locationProvider'];

  function config($urlProvider, $locationProvider) {
    $urlProvider.otherwise('/');

    $locationProvider.html5Mode({
      enabled:false,
      requireBase: false
    });

    $locationProvider.hashPrefix('!');
  }

  function run() {
    FastClick.attach(document.body);
  }

})();
