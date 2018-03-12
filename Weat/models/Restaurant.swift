//
//  Restaurant.swift
//  Weat
//
//  Created by Sean Becker on 2/22/18.
//  Copyright © 2018 Weat. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire
import GooglePlaces
import FBSDKLoginKit

class Restaurant {
    var latitude: Double?
    var longitude: Double?
    var price: String?
    var name: String?
    var image: UIImage?
    var google_link: String?
    var phone: String?
    var open_now: String?
    
    static func getRestaurantInfo(google_link: String, completion: @escaping (Restaurant) -> ()){
        let restaurant = Restaurant()
        restaurant.google_link = google_link
        var photo_url: String = ""
        
        // use google link to get details
        let info_url = "https://maps.googleapis.com/maps/api/place/details/json?placeid=\(String(describing: google_link))&key=\(kPlacesWebAPIKey)"
        Alamofire.request(info_url, method:.get, parameters:nil).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                var json = JSON(value)
                if let error_message: String = json["error_message"].string {
                    print("restaurant model error: " + error_message)
                } else {
                    restaurant.latitude = json["result"]["geometry"]["location"]["lat"].double
                    restaurant.longitude = json["result"]["geometry"]["location"]["lng"].double
                    restaurant.name = json["result"]["name"].string
                    restaurant.phone = json["result"]["formatted_phone_number"].string
                    switch json["result"]["open_now"].bool {
                    case true?:
                        restaurant.open_now = "Open"
                    default:
                        restaurant.open_now = "Closed"
                    }
                    // add more details here as needed
                    switch json["result"]["price_level"].int {
                    case 0?:
                        restaurant.price = "Free"
                    case 1?:
                        restaurant.price = "Inexpensive"
                    case 2?:
                        restaurant.price = "Moderate"
                    case 3?:
                        restaurant.price = "Expensive"
                    case 4?:
                        restaurant.price = "Very Expensive"
                    default:
                        restaurant.price = "Moderate"
                    }
                    // use details to get photo
                    if(json["result"]["photos"].array != nil) {
                        let jsonArr:[JSON] = json["result"]["photos"].array!
                        let photo_reference:String = jsonArr[0]["photo_reference"].string!
                        photo_url = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(String(photo_reference))&key=\(String(kPlacesWebAPIKey))"
                        Alamofire.request(photo_url, method:.get, parameters:nil).validate().responseData(completionHandler: {
                            (response) in
                            if(response.error == nil) {
                                if let data = response.data {
                                    restaurant.image = UIImage(data: data)
                                } else {
                                    restaurant.image = UIImage(named: "Explore")
                                }
                            } else {
                                print(response.error ?? "Couldn't get restaurant info from Google (Restaurant.swift)")
                            }
                            completion(restaurant)
                        })
                    } else {
                        completion(restaurant)
                    }
                }
            case .failure(let error):
                print(error)
                print("There was an error")
                completion(restaurant)
            }
        }
    }
    
    
    /*
     * Get menu for a restaurant, this function is for menu ONLY, for menu with friends ratings/comments, use "getRestaurantMenuWithRating()"
     * The result is a array of Menu_item with "rating" property equals to "nil"
     * Parameter: google_link, String
     * Access token is automatically obtained from local statics
     */
    static func getRestaurantMenu(google_link: String,completion: @escaping (([Menu_item]))->()){
        let url = "\(String(WeatAPIUrl))/restaurants/menu"
        let params = [
            "access_token": FBSDKAccessToken.current().tokenString!,
            "google_link": google_link
        ]
        var menu_items = [Menu_item]()
        Alamofire.request(url, method:.get, parameters:params).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                // Debug option
                print(json)
                for menu_item in json["menu_items"].arrayValue{
                    let category = menu_item["name"]
                    for i in menu_item["items"].arrayValue{
                        let item = Menu_item()
                        item.id = i["id"].intValue
                        item.category = category.stringValue
                        item.name = i["name"].stringValue
                        // Does not do anything with the rating
                        menu_items.append(item)
                        completion(menu_items)
                    }
                }
            case .failure(let error):
                print(error)
                completion(menu_items)
            }
        }
    }
    
    /*
     * Get menu for a restaurant along with the ratings, the ratings contains the (name of) author
     * The result is a array of Menu_item with ratings(might be null if no one has a rating for this item)
     * The ratings are from the user's friends ONLY
     * Access token is automatically obtained
     */
    static func getRestaurantMenuWithRating(google_link:String, completion: @escaping (([Menu_item]))->()){
        let url = "\(String(WeatAPIUrl))/restaurants/detail"
        let params = [
            "access_token": "test2", //FBSDKAccessToken.current().tokenString!,
            "google_link": google_link
        ]
        var menu_items = [Menu_item]()
        Alamofire.request(url, method:.get, parameters:params).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                // Debug option
                print(json)
                for menu_item in json["restaurant"]["menu_items"].arrayValue{
                    let category = menu_item["category"]
                    let item = Menu_item()
                    item.id = menu_item["id"].intValue
                    item.category = category.stringValue
                    item.name = menu_item["name"].stringValue
                    // Will implement rating later
                    for rating in menu_item["ratings"].arrayValue{
                        let r = Rating()
                        r.author = rating["user"]["name"].stringValue
                        r.food_rating = rating["food_rating"].intValue
                        r.id = rating["id"].intValue
                        r.rating_text = rating["rating_text"].stringValue
                        r.restaurant_id = json["restaurant"]["id"].intValue
                        r.menu_item_id = json["menu_item_id"].intValue
                        r.service_rating = nil
                        item.rating.append(r)
                    }
                    menu_items.append(item)
                }
            case .failure(let error):
                print(error)
            }
            completion(menu_items)
        }
    }
    
    /* TESTED
     * Get rating for a restaurant, this function is for ratings ONLY
     * The result is a array of Rating
     * Parameter: google_link, String
     * Access token is automatically obtained from local statics
     */
    static func getRestaurantRating(google_link: String,completion: @escaping (([Rating]))->()){
        let url = "\(String(WeatAPIUrl))/restaurants/comments"
        let params = [
            "access_token": FBSDKAccessToken.current().tokenString!,
            "google_link": google_link
        ]
        var ratings = [Rating]()
        Alamofire.request(url, method:.get, parameters:params).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                // Debug option
                print(json)
                for r in json["restaurant"]["ratings"].arrayValue{
                    let rating = Rating()
                    rating.id = r["id"].intValue
                    rating.restaurant_id = r["restaurant_id"].intValue
                    rating.food_rating = r["food_rating"].intValue
                    rating.service_rating = r["service_rating"].intValue
                    rating.rating_text = r["rating_text"].stringValue
                    let str = r["createdAt"].stringValue
                    let trimmedIsoString = str.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                    rating.time = ISO8601DateFormatter().date(from: trimmedIsoString)
                    // This is null because this is a rating for a restaurant not for a menu item
                    rating.menu_item_id = nil
                    // Null for now will implement later
                    rating.author = nil
                    ratings.append(rating)
                }
            case .failure(let error):
                print(error)
            }
            completion(ratings)
        }
    }
}
