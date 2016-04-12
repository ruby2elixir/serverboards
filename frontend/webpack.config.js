var webpack = require('webpack');
var path = require('path')

// To Reqrite index.html with proper bundle js
var HtmlWebpackPlugin = require('html-webpack-plugin')
var HTMLWebpackPluginConfig = new HtmlWebpackPlugin({
  template: __dirname + '/app/index.html',
  filename: 'index.html',
  inject: 'body'
});

var CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = {
    entry: [
      //'webpack/hot/only-dev-server',
      "./app/js/app.js"
    ],
    output: {
        path: __dirname + '/dist/',
        filename: "js/serverboards-[hash].js"
    },
    devtool: "source-map",
    module: {
        loaders: [
            { test: /\.js?$/, loaders: [/* 'react-hot', */ 'babel'], exclude: /node_modules/ },
            { test: /\.js$/, exclude: /node_modules/, loader: 'babel-loader'},
            { test: /\.css$/, loader: "style!css" },
            //{ test: /\.sass$/, exclude: /node_modules/, loaders: ["style","css?sourceMap","sass?sourceMap"]},
        ]
    },
    plugins: [
      new webpack.NoErrorsPlugin(),
      HTMLWebpackPluginConfig,
      new CopyWebpackPlugin([
        {from:'app/css', to:'css'},
        {from:'app/js/jquery-2.2.3.min.js', to:'js'},
        {from:'app/js/semantic.min.js', to:'js'},
      ])
    ],
    sassLoader: {
      includePaths: [path.resolve(__dirname, "./sass")]
    }
};
