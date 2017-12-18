var gulp = require('gulp');
var strip = require('gulp-strip-comments');
var uglify = require('gulp-uglify');
var pump = require('pump');
var babel = require('gulp-babel');

// Not currently in use.
// gulp.task('default', function () {
//     return gulp.src([
//         '*.js',
//         '!gulpfile.js',
//         '*.json',
//         'sessions/**/*',
//         '!sessions/**/*.dist',
//         '!sessions/**/*.json'
//     ])
//         .pipe(strip())
//         .pipe(gulp.dest(function (file) {
//             var dest = file.base.replace('sessions', 'dist');
//             return dest;
//         }));
// });

// Copy production files to dist folder.
gulp.task('copy', function (cb) {
    pump([
        gulp.src([
            'certs/winman.crt',
            'certs/winman.key',
            'views/**',
            '!views/**/schema/**/*.dist',
            '!views/static/swagger/schema/*.json'], { base: '.' }),
        gulp.dest('dist')
    ],
        cb
    );
});

// Copy remaining production files and remove comments.
gulp.task('strip', function (cb) {
    pump([
        gulp.src([
            'config/**',
            'middleware/**',
            'routes/**',
            '!routes/**/*.dist',
            '*.js',
            '*.json',
            '!gulpfile.js'], { base: '.' }),
        strip(),
        gulp.dest('dist')
    ],
        cb
    );
});
