import angular from 'angular';
import 'angular-animate';
import 'angular-sanitize';
import 'angular-ui-bootstrap';
import 'bootstrap';
import '@fortawesome/fontawesome-free/css/all.css';
import '../../assets/bootstrap.scss';

const app = angular.module('meepInstaller', ['ngAnimate', 'ngSanitize', 'ui.bootstrap']);
const languageFiles = require.context('../../lang', false, /\.json$/);

app.controller('InstallerController', ['$scope', '$timeout', function InstallerController($scope, $timeout) {
  const vm = this;

  vm.pages = [
    'pages/start.html',
    'pages/keyboard.html',
    'pages/disks.html',
    'pages/review.html',
  ];
  vm.state = {
    page: 0,
    language: 'en-us',
    keyboard: 'us',
    lang: {},
    disks: [],
    selectedDisk: '',
  };
  vm.pageTemplate = vm.pages[vm.state.page];
  vm.busy = false;
  vm.transitioning = false;
  vm.transitionClass = '';
  vm.installResult = null;

  vm.stepLabel = () => `Step ${String(vm.state.page).padStart(2, '0')} of ${String(vm.pages.length - 1).padStart(2, '0')}`;
  vm.isFirstPage = () => vm.state.page === 0;
  vm.isLastPage = () => vm.state.page === vm.pages.length - 1;
  vm.isNextDisabled = () => vm.busy || vm.transitioning || (vm.state.page === 2 && !vm.state.selectedDisk);

  vm.returnToOs = () => window.meepInstaller.returnToOs();

  vm.changeLanguage = async () => {
    try {
      const module = languageFiles(`./${vm.state.language}.json`);
      vm.state.lang = module.default || module;
    } catch (error) {
      console.error(`Unable to load language ${vm.state.language}`, error);
      vm.state.lang = {};
    }
    $scope.$evalAsync();
  };

  vm.back = () => {
    if (vm.state.page === 0) return;
    vm.goToPage(vm.state.page - 1);
  };

  vm.selectDisk = (disk) => {
    vm.state.selectedDisk = disk.path;
    vm.goToPage(vm.state.page + 1);
  };

  vm.goToPage = (page) => {
    if (vm.transitioning || page < 0 || page >= vm.pages.length) return;
    vm.transitioning = true;
    vm.transitionClass = 'fade-out';
    $timeout(() => {
      vm.state.page = page;
      vm.pageTemplate = vm.pages[page];
      vm.transitionClass = 'fade-in';
      $timeout(() => {
        vm.transitionClass = '';
        vm.transitioning = false;
      }, 250);
    }, 250);
  };

  vm.next = async () => {
    if (vm.isLastPage()) {
      vm.busy = true;
      try {
        const result = await window.meepInstaller.executeInstall(vm.state);
        vm.installResult = { type: result.ok ? 'success' : 'danger', message: result.pending ? vm.state.lang.review.installGated : result.message };
      } finally {
        vm.busy = false;
        $scope.$evalAsync();
      }
      return;
    }
    vm.goToPage(vm.state.page + 1);
  };

  vm.templateLoaded = () => {
    if (vm.state.page === 2) vm.loadDisks();
  };

  vm.loadDisks = async () => {
    try {
      vm.state.disks = await window.meepInstaller.listBlockDevices();
    } catch (error) {
      vm.state.disks = [{ name: 'Unavailable', path: error.message }];
    }
    $scope.$evalAsync();
  };

  vm.changeLanguage();
}]);
